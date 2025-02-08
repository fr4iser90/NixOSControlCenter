from typing import Optional, Union
from transformers import Trainer
from ..interfaces.trainer import ITrainer

class TransformersTrainerWrapper(ITrainer):
    """
    Wrapper class for the Trainer class from transformers.
    """

    def __init__(self, trainer: Trainer):
        self.trainer = trainer

    def train(self, resume_from_checkpoint: Optional[Union[str, bool]]):
        """
        Train the model.
        """
        return self.trainer.train(resume_from_checkpoint=resume_from_checkpoint)

    def save_model(self, output_dir: str, _internal_call=False):
        """Save the model."""
        self.trainer.save_model(output_dir, _internal_call=_internal_call)
