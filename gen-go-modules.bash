#!/usr/bin/env bash

modules=(
	benchinit
	corpus
	dockexec
	editorconfig
	fdroidcl
	garble
	gibot
	git-picked
	gofumpt
	gogrep
	goreduce
	interfacer
	nowt
	route
	sh{,/v3}
	unindent
	unparam
	xurls{,/v2}
	zstd
)

for mod in ${modules[@]}; do
	fullmod=mvdan.cc/${mod}
	echo "Module: $mod"

	reponame=${mod%/*}

	repouser=mvdan
	case ${reponame} in
	garble)
		repouser=burrowers
		;;
	esac

	# TODO: don't always point to master
	branch=master
	# if [[ $reponame != $mod ]]; then
	# 	// "reponame/v2", not just "reponame"
	# 	branch=${mod#*/}
	# fi

	rm -rf $mod
	mkdir -p $mod

	rm -f go.mod go.sum
	go mod init tmp 2>/dev/null

	go get $fullmod/...@latest 2>/dev/null
	for fullpkg in $(go list $fullmod/...); do
		if [[ $fullpkg == $fullmod ]]; then
			# a module's root index.html is written below
			continue
		fi
		pkg=${fullpkg#${fullmod}/}

		# Package paths redirect to pkg.go.dev for the docs.
		mkdir -p $mod/$pkg
		cat >$mod/$pkg/index.html <<EOF
<!DOCTYPE html>
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8">
	<meta name="go-import" content="${fullmod} git https://github.com/${repouser}/${reponame}">
	<meta name="go-source" content="${fullmod} https://github.com/${repouser}/${reponame} https://github.com/${repouser}/${reponame}/tree/${branch}{/dir} https://github.com/${repouser}/${reponame}/blob/${branch}{/dir}/{file}#L{line}">
	<meta http-equiv="refresh" content="0; url=https://pkg.go.dev/${fullpkg}">
</head>
</html>
EOF
	done


	# The module path should always redirect to GitHub.
	cat >$mod/index.html <<EOF
<!DOCTYPE html>
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8">
	<meta name="go-import" content="${fullmod} git https://github.com/${repouser}/${reponame}">
	<meta name="go-source" content="${fullmod} https://github.com/${repouser}/${reponame} https://github.com/${repouser}/${reponame}/tree/HEAD{/dir} https://github.com/${repouser}/${reponame}/blob/HEAD{/dir}/{file}#L{line}">
	<meta http-equiv="refresh" content="0; url=https://github.com/${repouser}/${reponame}">
</head>
</html>
EOF

	rm -f go.mod go.sum
done
