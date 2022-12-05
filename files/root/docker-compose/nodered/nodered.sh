#!/bin/sh
docker volume create --name node_red_data
docker run -p 1880:1880 -v node_red_data:/data --name mynodered nodered/node-red
