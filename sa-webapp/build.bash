#! /bin/bash

sudo apt install maven -y
mvn install
# java -jar target/sentiment-analysis-web-0.0.1-SNAPSHOT.jar --sa.logic.api.url=http://localhost:5000