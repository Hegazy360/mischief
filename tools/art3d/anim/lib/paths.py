"""Repo paths (plain Python: usable outside Blender)."""
import os


def repo_root():
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
