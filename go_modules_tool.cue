package main

import (
	"list"
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
	majorSuffix?: string

	_dirElems: [
		repoName,
		if majorSuffix != _|_ {
			majorSuffix,
		}
	]
	dir: pathpkg.Join(_dirElems, _os)

	fullName: pathpkg.Join(list.Concat([[_domain], _dirElems]), "unix")

	branch: string | *"master"
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
	// {repoName: "sh/moreinterp"},
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
					<meta name="go-import" content="\(m.fullName) git \(repoURL)">
					<meta name="go-source" content="\(m.fullName) \(repoURL) \(repoURL)/tree/HEAD{/dir} \(repoURL)/blob/HEAD{/dir}/{file}#L{line}">
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
				cmd: ["go", "get", m.fullName+"/..."]
				stderr: string // be silent
			}
			goList: exec.Run & {
				$after: goGet
				dir: mkdirTemp.path
				cmd: ["go", "list", m.fullName+"/..."]
				stdout: string
			}
			// Package paths redirect to pkg.go.dev for the docs.
			// A module's root index.html is written above.
			for fullp in strings.Fields(goList.stdout) if fullp != m.fullName {
				let subp = strings.TrimPrefix(fullp, m.fullName+"/")
				(subp): _writeFile & {
					_filename: pathpkg.Join([m.dir, subp, "index.html"], _os)
					_contents: """
						<!DOCTYPE html>
						<head>
							<meta http-equiv="content-type" content="text/html; charset=utf-8">
							<meta name="go-import" content="\(m.fullName) git \(repoURL)">
							<meta name="go-source" content="\(m.fullName) \(repoURL) \(repoURL)/tree/\(m.branch){/dir} \(repoURL)/blob/\(m.branch){/dir}/{file}#L{line}">
							<meta http-equiv="refresh" content="0; url=https://pkg.go.dev/\(fullp)">
						</head>
						</html>
						"""
				}
			}
		}
	}
}
