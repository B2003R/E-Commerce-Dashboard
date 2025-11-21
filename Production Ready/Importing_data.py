# import kagglehub
# from os import path
import pandas as pd
import glob
# Download latest version
# path = kagglehub.dataset_download("olistbr/brazilian-ecommerce")
path = r"C:\Users\rohit\.cache\kagglehub\datasets\olistbr\brazilian-ecommerce\versions\2"
all_files = glob.glob(path + "/*.csv")
# print("Path to dataset files:", path)
# The Data has been imported
for i in range(len(all_files)):
    data = pd.read_csv(all_files[i])
    print(data.info())
# print(all_files[1])
# print(data.info())
