#!/usr/bin/env bash

gpg --symmetric --cipher-algo AES256 -o .env.gpg .env