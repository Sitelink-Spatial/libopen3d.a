
echo "============== Pass 1 =============="
rm -Rf ./lib3 ./build ./pkg
echo "============== Pass 2 =============="
rm -Rf ./lib3 ./build ./pkg

find . | grep \.DS_Store | xargs rm
