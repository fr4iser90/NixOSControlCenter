"""Model interpretation and explainability module."""
import logging
from pathlib import Path
import numpy as np
import shap
import lime
import lime.lime_text
from sklearn.metrics import confusion_matrix
import matplotlib.pyplot as plt
import seaborn as sns
from typing import List, Dict, Any

logger = logging.getLogger(__name__)

class ModelInterpreter:
    """Handles model interpretation and explainability."""
    
    def __init__(self, model, tokenizer):
        self.model = model
        self.tokenizer = tokenizer
        
    def explain_prediction(self, text: str) -> Dict[str, Any]:
        """Generate SHAP and LIME explanations for a prediction."""
        try:
            # Get model prediction
            inputs = self.tokenizer(text, return_tensors="pt", truncation=True)
            prediction = self.model(**inputs)
            
            # SHAP explanation
            explainer = shap.Explainer(self.model, self.tokenizer)
            shap_values = explainer([text])
            
            # LIME explanation
            text_explainer = lime.lime_text.LimeTextExplainer(class_names=self.model.config.id2label)
            lime_exp = text_explainer.explain_instance(
                text,
                self.predict_proba,
                num_features=10
            )
            
            # Create visualization
            viz_path = self._save_explanation_plot(shap_values, lime_exp, text)
            
            return {
                'text': text,
                'prediction': prediction,
                'shap_values': shap_values.values.tolist(),
                'lime_explanation': lime_exp.as_list(),
                'visualization_path': str(viz_path)
            }
            
        except Exception as e:
            logger.error(f"Error generating explanation: {str(e)}")
            return {'error': str(e)}
    
    def analyze_errors(self, test_data: List[Dict]) -> Dict[str, Any]:
        """Analyze misclassified instances."""
        try:
            results = []
            for item in test_data:
                inputs = self.tokenizer(item['text'], return_tensors="pt", truncation=True)
                prediction = self.model(**inputs)
                if prediction.argmax() != item['label']:
                    explanation = self.explain_prediction(item['text'])
                    results.append({
                        'text': item['text'],
                        'true_label': item['label'],
                        'predicted_label': prediction.argmax().item(),
                        'explanation': explanation
                    })
            
            # Generate error analysis report
            report = self._generate_error_report(results)
            
            return {
                'misclassified_samples': results,
                'error_patterns': self._identify_error_patterns(results),
                'report': report
            }
            
        except Exception as e:
            logger.error(f"Error in error analysis: {str(e)}")
            return {'error': str(e)}
    
    def predict_proba(self, texts: List[str]) -> np.ndarray:
        """Get probability predictions for LIME."""
        try:
            inputs = self.tokenizer(texts, padding=True, truncation=True, return_tensors="pt")
            outputs = self.model(**inputs)
            probs = outputs.logits.softmax(dim=-1).detach().numpy()
            return probs
        except Exception as e:
            logger.error(f"Error in predict_proba: {str(e)}")
            return np.array([])
    
    def _save_explanation_plot(self, shap_values, lime_exp, text: str) -> Path:
        """Create and save visualization of explanations."""
        try:
            fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(15, 10))
            
            # Plot SHAP values
            shap.plots.text(shap_values, ax=ax1)
            
            # Plot LIME explanation
            lime_exp.as_pyplot_figure(ax=ax2)
            
            # Save plot
            plot_path = Path("visualizations/explanations")
            plot_path.mkdir(parents=True, exist_ok=True)
            file_path = plot_path / f"explanation_{hash(text)}.png"
            plt.savefig(file_path)
            plt.close()
            
            return file_path
            
        except Exception as e:
            logger.error(f"Error saving explanation plot: {str(e)}")
            return None
    
    def _identify_error_patterns(self, results: List[Dict]) -> Dict[str, Any]:
        """Identify common patterns in misclassified instances."""
        patterns = {
            'common_words': self._analyze_common_words([r['text'] for r in results]),
            'label_confusion': self._analyze_label_confusion(results),
            'text_length_distribution': self._analyze_text_length(results)
        }
        return patterns
    
    def _generate_error_report(self, results: List[Dict]) -> str:
        """Generate a detailed error analysis report."""
        report = []
        report.append("# Error Analysis Report")
        report.append("\n## Summary")
        report.append(f"Total misclassified samples: {len(results)}")
        
        # Add confusion matrix
        true_labels = [r['true_label'] for r in results]
        pred_labels = [r['predicted_label'] for r in results]
        cm = confusion_matrix(true_labels, pred_labels)
        
        # Save confusion matrix plot
        plt.figure(figsize=(10, 8))
        sns.heatmap(cm, annot=True, fmt='d')
        plt.title("Confusion Matrix of Misclassified Samples")
        plt.xlabel("Predicted Label")
        plt.ylabel("True Label")
        
        plot_path = Path("visualizations/error_analysis")
        plot_path.mkdir(parents=True, exist_ok=True)
        cm_path = plot_path / "confusion_matrix.png"
        plt.savefig(cm_path)
        plt.close()
        
        report.append(f"\nConfusion Matrix: {cm_path}")
        
        # Add sample analysis
        report.append("\n## Sample Analysis")
        for i, result in enumerate(results[:5]):  # Show first 5 examples
            report.append(f"\n### Example {i+1}")
            report.append(f"Text: {result['text']}")
            report.append(f"True Label: {result['true_label']}")
            report.append(f"Predicted Label: {result['predicted_label']}")
            report.append("Top Features (LIME):")
            for feature, importance in result['explanation']['lime_explanation'][:3]:
                report.append(f"- {feature}: {importance:.3f}")
        
        return "\n".join(report)
    
    def _analyze_common_words(self, texts: List[str]) -> Dict[str, int]:
        """Analyze frequently occurring words in misclassified texts."""
        from collections import Counter
        import re
        
        words = []
        for text in texts:
            words.extend(re.findall(r'\w+', text.lower()))
        return dict(Counter(words).most_common(10))
    
    def _analyze_label_confusion(self, results: List[Dict]) -> Dict[str, Dict[str, int]]:
        """Analyze which labels are commonly confused."""
        confusion = {}
        for result in results:
            true_label = str(result['true_label'])
            pred_label = str(result['predicted_label'])
            if true_label not in confusion:
                confusion[true_label] = {}
            if pred_label not in confusion[true_label]:
                confusion[true_label][pred_label] = 0
            confusion[true_label][pred_label] += 1
        return confusion
    
    def _analyze_text_length(self, results: List[Dict]) -> Dict[str, Any]:
        """Analyze text length distribution of misclassified samples."""
        lengths = [len(r['text'].split()) for r in results]
        return {
            'mean': np.mean(lengths),
            'median': np.median(lengths),
            'std': np.std(lengths),
            'min': min(lengths),
            'max': max(lengths)
        }
