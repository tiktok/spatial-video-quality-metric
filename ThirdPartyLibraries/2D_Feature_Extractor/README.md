
# Project Setup

This document provides instructions to set up the conda environment required for this project.

## Prerequisites

- Conda should be installed on your system. You can install Conda by following the instructions [here](https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html).

## Environment Setup

### 1. Create the Conda Environment

First, create a new conda environment with Python 3.9:

```bash
conda create -n reiqa2D python=3.9
```

### 2. Activate the Environment

Activate the newly created environment:

```bash
conda activate reiqa2D
```

### 3. Install PyTorch and torchvision with CUDA 11.7

Install PyTorch 1.13.1, torchvision 0.14.1, and CUDA 11.7:

```bash
conda install pytorch==1.13.1 torchvision==0.14.1 cudatoolkit=11.7 -c pytorch
```

### 4. Install Additional Dependencies

Once the environment is ready, install the additional libraries listed in the `requirements.txt` file:

```bash
pip install -r requirements.txt
```

The `requirements.txt` file includes the following libraries:

### 5. Verify Installation

You can verify that everything is installed correctly by running the following command:

```bash
python -c "import torch; print(torch.__version__); print(torch.cuda.is_available())"
```

This will print the PyTorch version and check if CUDA is available.

## Obtaining Quality Aware Features

Download the quality-aware trained model from [Google Drive](https://drive.google.com/file/d/1DYMx8omn69yXUmBFL728JD3qMLNogFt8/view?usp=sharing) and store in a folder named ```re-iqa_ckpts```. Finally, to obtain Re-IQA Quality-Aware features, run

```
python demo_quality_aware_feats.py --head mlp
```

## Obtaining Content Aware Features

We utilized the vanilla MoCo-v2 training code using ResNet-50 architecture and ImageNet database provided in the [PyContrast](https://github.com/HobbitLong/PyContrast) repository to train our Content Aware Module using the default settings. 

Download the content-aware trained model from [Google Drive](https://drive.google.com/file/d/1TO-5fmZFT2_nt99j4IZen6vmXUb_UL3n/view?usp=sharing) and store in a folder named ```re-iqa_ckpts```. Finally, to obtain Re-IQA Content-Aware features, run

```
python demo_content_aware_feats.py --head mlp
```

## Training Linear Regressor

We used Sklearn's Linear Regression Models with Regularization for training the final IQA model. We recommend using either one of [Ridge](https://scikit-learn.org/stable/modules/generated/sklearn.linear_model.Ridge.html) or [Elastic Net](https://scikit-learn.org/stable/modules/generated/sklearn.linear_model.ElasticNet.html) models and performing extensive hyper-parameter search for each database to extract maximum performance. 

# To-Do
add support for directly running on videos, current script runs on images only. 
