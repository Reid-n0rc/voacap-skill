"""
Unit tests for voacap_predict.py.

Regression coverage for the antenna-gain bug (see the git history / PR that
introduced this file): voacapl's ANTCALC subroutine
(vendor/voacapl/src/voacapw/antcalc.for) reads the propagation-input
filename into a FORTRAN CHARACTER*20 dummy argument. FORTRAN silently
truncates an over-length actual argument instead of raising an error, so a
too-long filename makes ANTCALC's OPEN(status='old') fail to find the
truncated name. ANTCALC then returns without regenerating the antenna gain
tables (gainNN.dat) for the run, and the rest of the run silently reads
whatever gainNN.dat happens to already exist on disk -- so antenna choice
has no effect (or the run crashes, if no stale gainNN.dat exists).

These tests are pure-Python: they don't require the voacapl binary or
~/itshfbc to be built, so they run in the fast "unit-tests" CI job. The
antenna-gain-actually-changes-the-result regression check that needs a
real voacapl build lives in scripts/run_tests.sh instead.
"""
import importlib.util
import io
import os
import sys
import uuid
from contextlib import redirect_stderr

import pytest

MODULE_PATH = os.path.join(
    os.path.dirname(__file__), "..", "scripts", "voacap_predict.py"
)


def _load_module():
    spec = importlib.util.spec_from_file_location("voacap_predict", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


vp = _load_module()


class TestGenerateRunTag:
    """generate_run_tag() feeds ANTCALC's CHARACTER*20 filename argument."""

    def test_tag_alone_fits_comfortably(self):
        tag = vp.generate_run_tag()
        assert len(tag) < vp.ANTCALC_FILENAME_LIMIT

    @pytest.mark.parametrize("extension", [".dat", ".out"])
    def test_tagged_filename_within_fortran_character20_limit(self, extension):
        for _ in range(1000):
            filename = f"{vp.generate_run_tag()}{extension}"
            assert len(filename) <= vp.ANTCALC_FILENAME_LIMIT, (
                f"{filename!r} is {len(filename)} chars, exceeds the "
                f"{vp.ANTCALC_FILENAME_LIMIT}-char FORTRAN CHARACTER*20 "
                "limit ANTCALC truncates filenames to"
            )

    def test_old_pid_timestamp_scheme_would_have_overflowed(self):
        """Documents why the old scheme (skill_<pid>_<unix time>) was buggy:
        it regularly produced filenames longer than the FORTRAN limit."""
        pid = 65083
        unix_time = 1788550118
        old_style = f"skill_{pid}_{unix_time}.dat"
        assert len(old_style) > vp.ANTCALC_FILENAME_LIMIT

    def test_tags_are_unique(self):
        tags = {vp.generate_run_tag() for _ in range(2000)}
        assert len(tags) == 2000

    def test_tag_is_deterministically_reproducible_shape(self, monkeypatch):
        fixed = uuid.UUID("12345678-9abc-def0-1234-56789abcdef0")
        monkeypatch.setattr(vp.uuid, "uuid4", lambda: fixed)
        assert vp.generate_run_tag() == "v123456789abc"


class TestFixedWidthFieldHelpers:
    """f()/i() write VOACAP's fixed-column ASCII card fields; both must
    fail loudly (not silently truncate, mirroring the FORTRAN-side risk)
    when a value doesn't fit."""

    def test_f_rejects_value_wider_than_field(self):
        with pytest.raises(ValueError):
            vp.f(5, 2, 12345.678)

    def test_f_right_justifies_within_field(self):
        assert vp.f(10, 3, 0.0) == "     0.000"

    def test_i_rejects_value_wider_than_field(self):
        with pytest.raises(ValueError):
            vp.i(3, 123456)

    def test_i_right_justifies_within_field(self):
        assert vp.i(5, 24) == "   24"


class TestAntennaField:
    """The ANTENNA card's filename column is a FORTRAN a21 field
    (antcalc.for: FORMAT(10X,4I5,F10.3,1X,A21,1X,F5.1,F10.4)); an
    over-length antenna path must be rejected rather than silently
    truncated (which would point ANTCALC at the wrong antenna file)."""

    def test_accepts_path_at_the_21_char_limit(self):
        path = "d" * 21
        line = vp.antenna_field(1, 1, 2, 30, path, 0.0, 0.1)
        assert path in line

    def test_rejects_path_over_21_chars(self):
        with pytest.raises(ValueError):
            vp.antenna_field(1, 1, 2, 30, "d" * 22, 0.0, 0.1)


class TestInputFileLengthGuard:
    """main() must refuse an over-length --input-file up front rather than
    handing voacapl a name ANTCALC will silently mis-truncate."""

    def _run_main(self, tmp_path, argv):
        run_dir = tmp_path / "itshfbc" / "run"
        run_dir.mkdir(parents=True)
        full_argv = [
            "voacap_predict.py",
            "--itshfbc", str(tmp_path / "itshfbc"),
            "--voacapl-bin", "/bin/true",
            "--tx-name", "A", "--tx-lat", "0", "--tx-lon", "0",
            "--rx-name", "B", "--rx-lat", "1", "--rx-lon", "1",
            "--month", "6", "--freqs", "14.2",
        ] + argv
        old_argv = sys.argv
        sys.argv = full_argv
        stderr = io.StringIO()
        try:
            with redirect_stderr(stderr):
                rc = vp.main()
        finally:
            sys.argv = old_argv
        return rc, stderr.getvalue()

    def test_overlong_input_file_is_rejected_before_running_voacapl(self, tmp_path):
        overlong = "a" * (vp.ANTCALC_FILENAME_LIMIT + 1) + ".dat"
        rc, err = self._run_main(tmp_path, ["--input-file", overlong])
        assert rc == 1
        assert "ANTCALC" in err
        assert not (tmp_path / "itshfbc" / "run" / overlong).exists()

    def test_input_file_exactly_at_limit_is_accepted(self, tmp_path, monkeypatch):
        # Exactly ANTCALC_FILENAME_LIMIT chars total -- must NOT be rejected
        # by the length guard itself (subprocess.run is stubbed out so this
        # only exercises argument validation, not a real voacapl run).
        exactly_at_limit = "a" * (vp.ANTCALC_FILENAME_LIMIT - 4) + ".dat"
        assert len(exactly_at_limit) == vp.ANTCALC_FILENAME_LIMIT

        called = {}

        class FakeResult:
            returncode = 1  # fail fast after the guard, before touching voacapl
            stdout = ""
            stderr = ""

        def fake_run(cmd, **kwargs):
            called["cmd"] = cmd
            return FakeResult()

        monkeypatch.setattr(vp.subprocess, "run", fake_run)
        rc, err = self._run_main(tmp_path, ["--input-file", exactly_at_limit])
        assert "cmd" in called, "the length guard should not have rejected this filename"
        assert "ANTCALC" not in err


class TestRootDirectoryLengthGuard:
    """main() must refuse an over-length --itshfbc / --run-dir up front
    rather than handing voacapl a path its fixed-length FORTRAN buffers
    will silently truncate (see VOACAPL_ROOT_DIRECTORY_LIMIT)."""

    def _run_main(self, tmp_path, argv):
        full_argv = [
            "voacap_predict.py",
            "--voacapl-bin", "/bin/true",
            "--tx-name", "A", "--tx-lat", "0", "--tx-lon", "0",
            "--rx-name", "B", "--rx-lat", "1", "--rx-lon", "1",
            "--month", "6", "--freqs", "14.2",
        ] + argv
        old_argv = sys.argv
        sys.argv = full_argv
        stderr = io.StringIO()
        try:
            with redirect_stderr(stderr):
                rc = vp.main()
        finally:
            sys.argv = old_argv
        return rc, stderr.getvalue()

    def test_overlong_itshfbc_is_rejected_before_running_voacapl(self, tmp_path):
        overlong = str(tmp_path / ("a" * vp.VOACAPL_ROOT_DIRECTORY_LIMIT))
        assert len(overlong) > vp.VOACAPL_ROOT_DIRECTORY_LIMIT
        rc, err = self._run_main(tmp_path, ["--itshfbc", overlong])
        assert rc == 1
        assert "VOACAPL_ROOT_DIRECTORY_LIMIT" in err or "itshfbc" in err

    def test_overlong_run_dir_is_rejected_before_running_voacapl(self, tmp_path):
        itshfbc = tmp_path / "itshfbc"
        (itshfbc / "run").mkdir(parents=True)
        overlong_run_dir = str(tmp_path / ("r" * vp.VOACAPL_ROOT_DIRECTORY_LIMIT))
        rc, err = self._run_main(
            tmp_path, ["--itshfbc", str(itshfbc), "--run-dir", overlong_run_dir]
        )
        assert rc == 1
        assert "run-dir" in err

    def test_itshfbc_at_limit_is_accepted(self, tmp_path, monkeypatch):
        base = tmp_path / ("a" * 5)
        (base / "run").mkdir(parents=True)
        itshfbc = str(base)
        assert len(itshfbc) <= vp.VOACAPL_ROOT_DIRECTORY_LIMIT

        called = {}

        class FakeResult:
            returncode = 1
            stdout = ""
            stderr = ""

        def fake_run(cmd, **kwargs):
            called["cmd"] = cmd
            return FakeResult()

        monkeypatch.setattr(vp.subprocess, "run", fake_run)
        rc, err = self._run_main(tmp_path, ["--itshfbc", itshfbc])
        assert "cmd" in called, "the length guard should not have rejected this path"
        assert "VOACAPL_ROOT_DIRECTORY_LIMIT" not in err


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))
