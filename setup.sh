#!/bin/bash



echo "export PYTHONPATH=$(pwd)/.lib/:$PYTHONPATH" >> ~/.zshrc
echo "export PYTHONPATH=$(pwd)/.lib/:$PYTHONPATH" >> ~/.bashrc
echo "export PYTHONPATH=$(pwd)/.lib/:$PYTHONPATH" >> ~/.profile

source ~/.bashrc


