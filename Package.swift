// swift-tools-version:5.3

import PackageDescription

let package = Package(
	name: "libgit2",
	platforms: [.iOS(.v13), .macOS(.v10_15)],
	products: [
		.library(
			name: "libgit2",
			targets: [
				"libgit2",
				"libssh2",
				"libssl",
				"libcrypto"
			]
		),
	],
	dependencies: [],
	targets: [
		.binaryTarget(
			name: "libgit2",
			url: "https://github.com/amine2233/libgit2-spm/releases/download/1.2.1/libgit2.zip",
			checksum: "e6cc5be713dc8e306c7a9464b37f82386edd81b6cd28c0c3e45185939fd90ca0"
		),
		.binaryTarget(
			name: "libssh2",
			url: "https://github.com/amine2233/libgit2-spm/releases/download/1.2.1/libssh2.zip",
			checksum: "027093a75d967c78fed719c6d80ce18e98b14903a063fcf6151f8a5591b53a60"
		),
		.binaryTarget(
			name: "libssl",
			url: "https://github.com/amine2233/libgit2-spm/releases/download/1.2.1/libssl.zip",
			checksum: "b03321b3d183a827c07e2fd778bd63ad1742e50fea651a561d02708108806204"
		),
		.binaryTarget(
			name: "libcrypto",
			url: "https://github.com/amine2233/libgit2-spm/releases/download/1.2.1/libcrypto.zip",
			checksum: "05174ed4d28e17f03a6f527521fc2bd17a7ce977525321780203489e33c7ad55"
		),
	]
)
