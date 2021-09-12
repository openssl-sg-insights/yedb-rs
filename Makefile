VERSION=0.1.0

all: test

test:
	cargo build --features server
	./target/debug/yedb-server /tmp/yedb-test-db1 --pid-file /tmp/yedb-server-test.pid -v &
	sleep 0.1
	#cargo test -- --test-threads=1 --nocapture
	cargo test --features client-sync,client-async -- --nocapture
	kill `cat /tmp/yedb-server-test.pid`
	sleep 0.5
	rm -rf /tmp/yedb-test-db1

clean:
	rm -rf _build
	cargo clean

tag:
	git tag -a v${VERSION} -m v${VERSION}
	git push origin --tags

ver:
	sed -i 's/^version = ".*/version = "${VERSION}"/g' Cargo.toml
	sed -i 's/^pub const VERSION:.*/pub const VERSION: \&str = "${VERSION}";/g' src/lib.rs

doc:
	grep -v "^//!" src/lib.rs > src/lib.rs.tmp
	sed 's|^|//! |g' README.md > src/lib.rs
	cat src/lib.rs.tmp >> src/lib.rs
	rm -f src/lib.rs.tmp
	cargo doc

release: pub tag pkg

pub: doc test publish-cargo-crate

publish-cargo-crate:
	cargo publish

pkg:
	rm -rf _build
	mkdir -p _build
	cross build --target x86_64-unknown-linux-musl --release --features server,cli
	cross build --target i686-unknown-linux-musl --release --features server,cli
	cross build --target arm-unknown-linux-musleabihf --release --features server,cli
	cross build --target aarch64-unknown-linux-musl --release --features server,cli
	cd target/x86_64-unknown-linux-musl/release && tar czvf ../../../_build/yedb-${VERSION}-x86_64-musl.tar.gz yedb-server yedb-cli
	cd target/i686-unknown-linux-musl/release && tar czvf ../../../_build/yedb-${VERSION}-i686-musl.tar.gz yedb-server yedb-cli
	cd target/arm-unknown-linux-musleabihf/release && tar czvf ../../../_build/yedb-${VERSION}-arm-musleabihf.tar.gz yedb-server yedb-cli
	cd target/aarch64-unknown-linux-musl/release && \
			aarch64-linux-gnu-strip yedb-server && \
			aarch64-linux-gnu-strip yedb-cli && \
			tar czvf ../../../_build/yedb-${VERSION}-aarch64-musl.tar.gz yedb-server yedb-cli
	cd _build && echo "" | gh release create v$(VERSION) -t "v$(VERSION)" \
			yedb-${VERSION}-arm-musleabihf.tar.gz \
			 yedb-${VERSION}-i686-musl.tar.gz \
			 yedb-${VERSION}-x86_64-musl.tar.gz \
			yedb-${VERSION}-aarch64-musl.tar.gz
