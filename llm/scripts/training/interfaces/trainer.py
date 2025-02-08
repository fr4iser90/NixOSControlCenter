from abc import ABC, abstractmethod
from typing import Optional, Union

class ITrainer(ABC):
    """
    Interface for the Trainer class from transformers.
    """

    @abstractmethod
    def train(self, resume_from_checkpoint: Optional[Union[str, bool]]):
        """
        Train the model.
        """
        raise NotImplementedError

    @abstractmethod
    def save_model(self, output_dir: str, _internal_call=False):
        """Save the model."""
        raise NotImplementedError
