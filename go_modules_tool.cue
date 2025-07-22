package main

import (
	"strings"
	pathpkg "path"
	"tool/exec"
	"tool/file"
)

_os: string @tag(os,var=os)
_domain: "mvdan.cc"
#Module: {
	owner: string | *"mvdan"
	repoName!: string
	subDir: string | *""
	majorSuffix: string | *""

	dir: pathpkg.Join([repoName, subDir, majorSuffix], _os)

	// NOTE: to support e.g. mvdan.cc/repo/subdir/v2 we will need the subdirectory feature
	// for go-import from Go 1.25 and later, as the VCS would host the code in the subdirectory "subdir"
	// but the root module prefix could only be "mvdan.cc/repo".
	// TODO: the go-source meta tags likely need adjusting when subDir is non-empty.
	// Test that out once moreinterp has a package for us to use.
	rootModPath: pathpkg.Join([_domain, repoName, majorSuffix], "unix")
	modPath:     pathpkg.Join([_domain, repoName, subDir, majorSuffix], "unix")
}

_modules: [...#Module] & [
	{repoName: "benchinit"},
	{repoName: "bitw"},
	{repoName: "corpus"},
	{repoName: "dockexec"},
	{repoName: "editorconfig"},
	{repoName: "fdroidcl"},
	{repoName: "garble", owner: "burrowers"},
	{repoName: "git-picked"},
	{repoName: "gofumpt"},
	{repoName: "gogrep"},
	{repoName: "goreduce"},
	{repoName: "interfacer"},
	{repoName: "nowt"},
	{repoName: "responsefile"},
	{repoName: "route"},
	{repoName: "sh"},
	{repoName: "sh", majorSuffix: "v3"},
	{repoName: "sh", subDir: "moreinterp"},
	{repoName: "unindent"},
	{repoName: "unparam"},
	{repoName: "xurls"},
	{repoName: "xurls", majorSuffix: "v2"},
	{repoName: "zstd"},
]

_foo: exec.Run

// TODO: why can't we wait for all subtasks before we start?
// it would be nice for "generate" to clean them all first.
command: clean: {
	for m in _modules {
		(m.repoName): file.RemoveAll & {
			path: m.repoName
		}
	}
}
_writeFile: {
	_filename!: string
	_contents!: string
	
	mkdir: file.MkdirAll & {
		path: pathpkg.Dir(_filename, _os)
	}
	write: file.Create & {
		$after: mkdir
		filename: _filename
		contents: _contents + "\n"
	}
}
command: generate: {
	for m in _modules {
		let repoURL = "https://github.com/\(m.owner)/\(m.repoName)"
		// The module path is always present, and it should redirect to GitHub.
		mod: (m.dir): _writeFile & {
			_filename: pathpkg.Join([m.dir, "index.html"], _os)
			_contents: """
				<!DOCTYPE html>
				<head>
					<meta http-equiv="content-type" content="text/html; charset=utf-8">
					<meta name="go-import" content="\(m.rootModPath) git \(repoURL)">
					<meta name="go-source" content="\(m.rootModPath) \(repoURL) \(repoURL)/tree/HEAD{/dir} \(repoURL)/blob/HEAD{/dir}/{file}#L{line}">
					<meta http-equiv="refresh" content="0; url=\(repoURL)">
				</head>
				</html>
				"""
		}
		pkg: (m.dir): {
			mkdirTemp: file.MkdirTemp & {
				pattern: "mvdan.cc-mod-*"
			}
			goInit: exec.Run & {
				$after: mkdirTemp
				dir: mkdirTemp.path
				cmd: ["go", "mod", "init", "test"]
				stderr: string // be silent
			}
			goGet: exec.Run & {
				$after: goInit
				dir: mkdirTemp.path
				cmd: ["go", "get", m.modPath+"/..."]
				stderr: string // be silent
			}
			goList: exec.Run & {
				$after: goGet
				dir: mkdirTemp.path
				cmd: ["go", "list", m.modPath+"/..."]
				stdout: string
			}
			// Package paths redirect to pkg.go.dev for the docs.
			// A module's root index.html is written above.
			for fullp in strings.Fields(goList.stdout) if fullp != m.modPath {
				let subp = strings.TrimPrefix(fullp, m.modPath+"/")
				(subp): _writeFile & {
					_filename: pathpkg.Join([m.dir, subp, "index.html"], _os)
					_contents: """
						<!DOCTYPE html>
						<head>
							<meta http-equiv="content-type" content="text/html; charset=utf-8">
							<meta name="go-import" content="\(m.modPath) git \(repoURL)">
							<meta name="go-source" content="\(m.modPath) \(repoURL) \(repoURL)/tree/HEAD{/dir} \(repoURL)/blob/HEAD{/dir}/{file}#L{line}">
							<meta http-equiv="refresh" content="0; url=https://pkg.go.dev/\(fullp)">
						</head>
						</html>
						"""
				}
			}
		}
	}
}
