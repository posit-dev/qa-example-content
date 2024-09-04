import pandas as pd
import os
data_file_path = os.path.join(os.getcwd(), 'data-files', '20x1M.parquet')
df = pd.read_parquet(data_file_path, engine='pyarrow')
