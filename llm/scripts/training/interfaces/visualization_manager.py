from abc import ABC, abstractmethod

class IVisualizationManager(ABC):
    """
    Interface for the VisualizationManager class.
    """

    @abstractmethod
    def start_server(self):
        """
        Starts the visualization server.
        """
        raise NotImplementedError
