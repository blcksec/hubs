set -e

#BLDR_HAB_TOKEN='_Qk9YLTEKYmxkci0yMDE3M...'
#BLDR_RET_TOKEN='_Qk9YLTEKYmxkci0yMDE5M...'
#BLDR_RET_PUB_B64='U0lHLVBVQi0xCm1vemls...'

mkdir -p /hab/cache/keys/
echo $BLDR_HAB_TOKEN > /hab/cache/keys/mozillareality_hab
echo $BLDR_RET_TOKEN > /hab/cache/keys/mozillareality_ret

export HAB_ORIGIN=mozillareality
export HAB_ORIGIN_KEYS=mozillareality_hab


### build
node --version; npm --version; tsc --version;
export BASE_ASSETS_PATH="$(echo "base_assets_path" | sha256sum | cut -d' ' -f1)/" # HACK need a trailing slash so webpack'ed semantics line up

echo "### building client"
npm ci --no-progress 1>/dev/null && npm run build

echo "### building admin"
cd admin && npm ci --no-progress 1>/dev/null && npm run build && cp -R dist/* ../dist && cd ..

echo "### repackaging"
mkdir -p dist/pages
mv dist/*.html dist/pages
mv dist/hub.service.js dist/pages || true
mv dist/schema.toml dist/pages ||true

echo "### build hab pkg"
export HAB_AUTH_TOKEN=$BLDR_HAB_TOKEN

cat > habitat/plan.sh << 'EOF'
pkg_name=hubs
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="1.0.0"
pkg_license=('MPLv2')
pkg_description="Duck-powered web-based social VR."
pkg_upstream_url="https://hubs.mozilla.com/"
pkg_build_deps=(
    core/coreutils/8.32/20210826054709
    core/bash/5.1/20210826055113
    mozillareality/node16/16.16.0/20220729014143
    core/git/2.31.0/20211016175551
)

pkg_deps=(
    core/aws-cli/1.16.118/20190305224525 # AWS cli used for run hook when uploading to S3
)

do_build() {
  # Avoid using git:// and ssh
  git config --global url."https://github.com/".insteadOf git@github.com:
  git config --global url."https://".insteadOf git://
  # We inject a random token into the build for the base assets path
  export BASE_ASSETS_PATH="$(echo "base_assets_path" | sha256sum | cut -d' ' -f1)/" # HACK need a trailing slash so webpack'ed semantics line up
  export BUILD_VERSION="${pkg_version}.$(echo $pkg_prefix | cut -d '/' -f 7)"
}

do_install() {
  cp -R dist "${pkg_prefix}"
}
EOF

./bio pkg build -k mozillareality .

### upload
echo "### upload hab pkg"
export HAB_BLDR_URL="https://bldr.reticulum.io"
export HAB_AUTH_TOKEN=$BLDR_RET_TOKEN
export HAB_ORIGIN_KEYS=mozillareality_ret
echo $BLDR_RET_PUB_B64 | base64 -d > /hab/cache/keys/mozillareality-20190117233449.pub
cat /hab/cache/keys/mozillareality-20190117233449.pub
hart="/hab/cache/artifacts/$HAB_ORIGIN-hubs*.hart"
ls -lha $hart
bio pkg upload $hart
rm -rf $hart
