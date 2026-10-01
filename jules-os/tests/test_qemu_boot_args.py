#!/usr/bin/env python3
import unittest
import os
import re

class TestQEMUBootArgs(unittest.TestCase):
    def setUp(self):
        self.test_file = os.path.join(os.path.dirname(__file__), 'qemu_boot_test.py')
        with open(self.test_file, 'r') as f:
            self.content = f.read()

    def test_rootfs_arg_present(self):
        # We need to make sure root=/dev/ram0 rw is passed in the non-universal boot path
        self.assertIn("root=/dev/ram0 rw", self.content,
                      "The QEMU boot test MUST include root=/dev/ram0 rw to mount the rootfs")

    def test_memory_arg_present(self):
        self.assertIn('"-m", "2048M"', self.content, "QEMU memory must be 2048M to prevent kernel panic")

class TestBuildTimeouts(unittest.TestCase):
    def setUp(self):
        self.build_script = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'build.sh')
        with open(self.build_script, 'r') as f:
            self.content = f.read()

    def test_syslinux_timeout(self):
        self.assertIn("TIMEOUT 1", self.content, "Syslinux timeout must be 1 to prevent infinite load during QEMU tests")

    def test_grub_timeout(self):
        self.assertIn("set timeout=1", self.content, "GRUB timeout must be 1 to prevent infinite load during QEMU tests")

if __name__ == '__main__':
    unittest.main()
