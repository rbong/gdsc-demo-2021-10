#!/usr/bin/env bash

set -e

echo "== Checking yarn =="

yarn --version

echo "== Installing app dependencies =="

cd app
yarn install

cd ..

echo "== Installing API dependencies =="

cd api
yarn install

cd ..

echo "== Building app =="

cd app
yarn build

cd ..

echo "== Building Swagger spec =="

cd api
yarn swagger

cd ..
