#!/bin/bash

# REPOSITORY: https://github.com/alwyn974/bdsh_tests

################
#              #
#    Colors    #
#              #
################

ESC='\033['
NC="${ESC}0m"
RED="${ESC}0;31m"
GREEN="${ESC}0;32m"

function printColor() {
  echo -e "${1}${NC}"
}

BINARY_NAME=bdsh
PASSED=""
FAILED=""
FILE="test_file.json"

function fail() {
  printColor "${RED}Failed: $*"
  FAILED+=1
}

function pass() {
  printColor "${GREEN}Passed"
  PASSED+=1
}

function tests() {
  echo "Testing bdsh..."
  rm -f "$FILE"

  echo "Checking database file management..."
  expect_exit_code "Creating database with -f" 0 -f "$FILE" create database
  rm -f "$FILE"

  echo "$FILE" >.bdshrc
  expect_exit_code "Creating database with .bdshrc" 0 create database
  rm -f "$FILE"
  rm -f ".bdshrc"

  export BDSH_File="$FILE"
  expect_exit_code "Creating database with env variable 'BDSH_File'" 0 create database
  rm -f "$FILE"

  expect_exit_code "Creating database with --file=" 0 "--file=$FILE" create database
  rm -f "$FILE"

  expect_exit_code "Checking -f empty" 1 -f
  expect_exit_code "Checking double -f" 1 -f "$FILE" -f "$FILE" create database
  expect_exit_code "Checking double -j" 1 -f "$FILE" -j -j create database

  echo "Cheking help"
  expect_exit_code "Checking help" 0 -h
  expect_exit_code "Checking help" 0 --help
  expect_exit_code "Checking help" 0

  echo "Checking bad option"
  expect_exit_code "Checking bad option" 1 -toto
  expect_exit_code "Checking bad option" 1 -wtf
  expect_exit_code "Checking bad option" 1 -ow
  expect_exit_code "Checking bad option" 1 --nothing

  echo "Checking no command after option"
  expect_exit_code "Checking no command after option" 1 -f "$FILE"

  echo "Checking option after command"
  expect_exit_code "Checking option after command" 1 -f "$FILE" create database -j
  expect_exit_code "Checking multiple option after command" 1 -f "$FILE" create database -j -h
  expect_exit_code "Checking bad option after command" 1 -f "$FILE" create databse -ow

  echo "Checking valid command"
  expect_exit_code "Checking create database keyword" 0 -f "$FILE" create database
  expect_exit_code "Checking create table keyword" 0 -f "$FILE" create table user id
  expect_exit_code "Checking insert keyword" 0 -f "$FILE" insert user "id=1"
  expect_exit_code "Checking select keyword" 0 -f "$FILE" select user id
  expect_exit_code "Checking update keyword" 0 -f "$FILE" update user "id=2" where "id=1"
  expect_exit_code "Checking delete keyword" 0 -f "$FILE" delete user where "id=1"
  rm "$FILE"

  echo "Checking invalid command"
  expect_exit_code "Checking invalid command" 1 -f "$FILE" creat
  expect_exit_code "Checking invalid command" 1 -f "$FILE" inset
  expect_exit_code "Checking invalid command" 1 -f "$FILE" selct
  expect_exit_code "Checking invalid command" 1 -f "$FILE" upate
  expect_exit_code "Checking invalid command" 1 -f "$FILE" dlete

  echo "Checking command with no request"
  expect_exit_code "Valid command without request" 1 -f "$FILE" create
  expect_exit_code "Valid command without request" 1 -f "$FILE" insert
  expect_exit_code "Valid command without request" 1 -f "$FILE" select
  expect_exit_code "Valid command without request" 1 -f "$FILE" update
  expect_exit_code "Valid command without request" 1 -f "$FILE" delete

  echo "Checking create command"
  rm -f "$FILE"
  expect_exit_code "Create database" 0 -f "$FILE" create database
  expect_exit_code "Database already exist" 1 -f "$FILE" create database
  rm -f "$FILE"

  expect_exit_code_and_json "Create database" 0 '{}' -f "$FILE" create database
  expect_exit_code_and_json "Create table 1" 0 '{"desc_user": ["id", "firstname", "lastname"], "data_user": []}' -f "$FILE" create table user id,firstname,lastname
  expect_exit_code_and_json "Create table 2" 0 '{"desc_user": ["id", "firstname", "lastname"], "desc_age": ["id", "age"], "data_user": [], "data_age": []}' -f "$FILE" create table age id,age
  expect_exit_code_and_json "Create table 3" 0 '{"desc_user": ["id", "firstname", "lastname"], "desc_age": ["id", "age"], "desc_toto": ["id", "toto"], "data_user": [], "data_age": [], "data_toto": []}' -f "$FILE" create table toto id,toto


}

function expect_exit_code_and_json() {
  local msg="$1"
  local expected_code="$2"
  local json="$3"
  shift
  shift
  shift
  echo "---------------------------------------------"
  echo "Tests: $msg"
  echo "./$BINARY_NAME $*"
  echo "-----"
  echo "Expectation: Exit code must be $expected_code"
  echo "Expectation: Json must be $json"
  echo "---"
  EXIT1=$expected_code

  ./$BINARY_NAME "$@"
  EXIT2=$?

  if [ ! "$EXIT1" = "$EXIT2" ]; then
    fail "Exit code are different (expected $EXIT1, got $EXIT2)."
    return
  fi

  jsonTest=$(cat "$FILE" | jq -reM)
  goodJson=$(echo "$json" | jq -reM)

  if [ ! "$goodJson" = "$jsonTest" ]; then
    fail "Json is not equivalent (expected $goodJson, got $jsonTest)"
    return
  fi

  pass
}

function expect_exit_code() {
  local msg="$1"
  local expected_code="$2"
  shift
  shift
  echo "---------------------------------------------"
  echo "Test: $msg"
  echo "./$BINARY_NAME $*"
  echo "-----"
  echo "Expectation: Exit code must be $expected_code"
  echo "---"
  EXIT1=$expected_code

  ./$BINARY_NAME "$@"
  EXIT2=$?

  if [ ! "$EXIT1" = "$EXIT2" ]; then
    fail "Exit code are different (expected $EXIT1, got $EXIT2)."
    return
  fi
  pass
}

function check_binary() {
  if [ ! -f "./$BINARY_NAME" ]; then
    echo "./$BINARY_NAME not found !"
    exit 1
  elif [ -z "$(which jq)" ]; then
    echo "You need jq command for the tests"
    echo "Please install it with:"
    echo "Ubuntu => sudo apt install jq"
    echo "Fedora => sudo dnf install jq"
  fi
}

function total() {
  echo -e "\nTests passed: $(echo -n $PASSED | wc -m). Tests failed: $(echo -n $FAILED | wc -m)."
}

function main() {
  if [ -n "$1" ]; then
    BINARY_NAME="$1"
  fi
  check_binary
  tests
  total
}

main "$@"
