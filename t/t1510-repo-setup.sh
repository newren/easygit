#!/bin/sh

test_description='Tests of cwd/prefix/worktree/gitdir setup in all cases'

. ./test-lib.sh

#
# A few rules for repo setup:
#
# 1. GIT_DIR is relative to user's cwd. --git-dir is equivalent to
#    GIT_DIR.
#
# 2. .git file is relative to parent directory. .git file is basically
#    symlink in disguise. The directory where .git file points to will
#    become new git_dir.
#
# 3. core.worktree is relative to git_dir.
#
# 4. GIT_WORK_TREE is relative to user's cwd. --work-tree is
#    equivalent to GIT_WORK_TREE.
#
# 5. GIT_WORK_TREE/core.worktree is only effective if GIT_DIR is set
#    Uneffective worktree settings should be warned.
#
# 6. Effective GIT_WORK_TREE overrides core.worktree and core.bare
#
# 7. Effective core.worktree conflicts with core.bare
#
# 8. If GIT_DIR is set but neither worktree nor bare setting is given,
#    original cwd becomes worktree.
#
# 9. If .git discovery is done inside a repo, the repo becomes a bare
#    repo. .git discovery is performed if GIT_DIR is not set.
#
# 10. If no worktree is available, cwd remains unchanged, prefix is
#     NULL.
#
# 11. When user's cwd is outside worktree, cwd remains unchanged,
#     prefix is NULL.
#

test_repo() {
	(
	cd "$1" &&
	if test -n "$2"; then GIT_DIR="$2" && export GIT_DIR; fi &&
	if test -n "$3"; then GIT_WORK_TREE="$3" && export GIT_WORK_TREE; fi &&
	rm -f trace &&
	GIT_TRACE="`pwd`/trace" git symbolic-ref HEAD >/dev/null &&
	grep '^setup: ' trace >result &&
	test_cmp expected result
	)
}

# Bit 0 = GIT_WORK_TREE
# Bit 1 = GIT_DIR
# Bit 2 = core.worktree
# Bit 3 = .git is a file
# Bit 4 = bare repo
# Case# = encoding of the above 5 bits

#
# Case #0
#
############################################################
#
# Input:
#
#  - GIT_WORK_TREE is not set
#  - GIT_DIR is not set
#  - core.worktree is not set
#  - .git is a directory
#  - core.bare is not set, cwd is outside .git
#
# Output:
#
#  - worktree is .git's parent directory
#  - cwd is at worktree root dir
#  - prefix is calculated
#  - git_dir is set to ".git"
#  - cwd can't be outside worktree

test_expect_success '#0: setup' '
	unset GIT_DIR GIT_WORK_TREE &&
	mkdir 0 0/sub &&
	cd 0 && git init && cd ..
'

test_expect_success '#0: at root' '
	cat >0/expected <<EOF &&
setup: git_dir: .git
setup: worktree: $TRASH_DIRECTORY/0
setup: cwd: $TRASH_DIRECTORY/0
setup: prefix: (null)
EOF
	test_repo 0
'

test_expect_success '#0: in subdir' '
	cat >0/sub/expected <<EOF &&
setup: git_dir: .git
setup: worktree: $TRASH_DIRECTORY/0
setup: cwd: $TRASH_DIRECTORY/0
setup: prefix: sub/
EOF
	test_repo 0/sub
'

#
# case #1
#
############################################################
#
# Input:
#
#  - GIT_WORK_TREE is set
#  - GIT_DIR is not set
#  - core.worktree is not set
#  - .git is a directory
#  - core.bare is not set, cwd is outside .git
#
# Output:
#
# GIT_WORK_TREE is ignored -> #0

test_expect_success '#1: setup' '
	unset GIT_DIR GIT_WORK_TREE &&
	mkdir 1 1/sub 1.wt 1.wt/sub 1/wt 1/wt/sub &&
	cd 1 &&
	git init &&
	GIT_WORK_TREE=non-existent &&
	export GIT_WORK_TREE &&
	cd ..
'

test_expect_failure '#1: at root' '
	cat >1/expected <<EOF &&
setup: git_dir: .git
setup: worktree: $TRASH_DIRECTORY/1
setup: cwd: $TRASH_DIRECTORY/1
setup: prefix: (null)
EOF
	test_repo 1
'

test_expect_failure '#1: in subdir' '
	cat >1/sub/expected <<EOF &&
setup: git_dir: .git
setup: worktree: $TRASH_DIRECTORY/1
setup: cwd: $TRASH_DIRECTORY/1
setup: prefix: sub/
EOF
	test_repo 1/sub
'

#
# case #2
#
############################################################
#
# Input:
#
#  - GIT_WORK_TREE is not set
#  - GIT_DIR is set
#  - core.worktree is not set
#  - .git is a directory
#  - core.bare is not set, cwd is outside .git
#
# Output:
#
#  - worktree is at original cwd
#  - cwd is unchanged
#  - prefix is NULL
#  - git_dir is set to $GIT_DIR
#  - cwd can't be outside worktree

test_expect_success '#2: setup' '
	unset GIT_DIR GIT_WORK_TREE &&
	mkdir 2 2/sub &&
	cd 2 && git init && cd ..
'

test_expect_success '#2: at root' '
	cat >2/expected <<EOF &&
setup: git_dir: $TRASH_DIRECTORY/2/.git
setup: worktree: $TRASH_DIRECTORY/2
setup: cwd: $TRASH_DIRECTORY/2
setup: prefix: (null)
EOF
	test_repo 2 "$TRASH_DIRECTORY/2/.git"
'

test_expect_success '#2: in subdir' '
	cat >2/sub/expected <<EOF &&
setup: git_dir: $TRASH_DIRECTORY/2/.git
setup: worktree: $TRASH_DIRECTORY/2/sub
setup: cwd: $TRASH_DIRECTORY/2/sub
setup: prefix: (null)
EOF
	test_repo 2/sub "$TRASH_DIRECTORY/2/.git"
'

test_expect_success '#2: relative GIT_DIR at root' '
	cat >2/expected <<EOF &&
setup: git_dir: .git
setup: worktree: $TRASH_DIRECTORY/2
setup: cwd: $TRASH_DIRECTORY/2
setup: prefix: (null)
EOF
	test_repo 2 .git
'

test_expect_success '#2: relative GIT_DIR in subdir' '
	cat >2/sub/expected <<EOF &&
setup: git_dir: ../.git
setup: worktree: $TRASH_DIRECTORY/2/sub
setup: cwd: $TRASH_DIRECTORY/2/sub
setup: prefix: (null)
EOF
	test_repo 2/sub ../.git
'

test_done
