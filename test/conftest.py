import os
import sys

from pathlib import Path
from collections import namedtuple

from container_ci_suite.utils import check_variables

if not check_variables():
    sys.exit(1)

TAGS = {
    "rhel8": "-el8",
    "rhel9": "-el9",
    "rhel10": "-el10",
}
TEST_DIR = Path(__file__).parent.absolute()
Vars = namedtuple(
    "Vars",
    [
        "OS",
        "VERSION",
        "IMAGE_NAME",
        "TEST_DIR",
        "TAG",
        "TEST_APP",
        "VERY_LONG_DB_NAME",
        "VERY_LONG_USER_NAME",
    ],
)
VERSION = os.getenv("VERSION")
OS = os.getenv("TARGET").lower()
TEST_APP = TEST_DIR / "test-app"
VERY_LONG_DB_NAME = "very_long_database_name_" + "x" * 40
VERY_LONG_USER_NAME = "very_long_user_name_" + "x" * 40
VARS = Vars(
    OS=OS,
    VERSION=VERSION,
    IMAGE_NAME=os.getenv("IMAGE_NAME"),
    TEST_DIR=Path(__file__).parent.absolute(),
    TAG=TAGS.get(OS),
    TEST_APP=TEST_APP,
    VERY_LONG_DB_NAME=VERY_LONG_DB_NAME,
    VERY_LONG_USER_NAME=VERY_LONG_USER_NAME,
)
