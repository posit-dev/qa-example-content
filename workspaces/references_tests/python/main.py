import sys
import os

# Ensure the script directory is in sys.path
script_dir = os.path.dirname(os.path.abspath(__file__))  # Get current script's directory
print(script_dir)
sys.path.append(script_dir)

# Now import helper
from helper import add

result = add(2, 3)
print(f"Result from main.py: {result}")