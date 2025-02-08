from abc import ABC, abstractmethod
from typing import Tuple
from datasets import Dataset

class IDatasetManager(ABC):
    """
    Interface for the DatasetManager class.
    """

    @abstractmethod
    def load_and_validate_processed_datasets(self) -> Tuple[Dataset, Dataset]:
        """
        Loads and validates the processed training and evaluation datasets.
        """
        raise NotImplementedError
