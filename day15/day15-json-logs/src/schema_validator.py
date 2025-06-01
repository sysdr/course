import json
import os
from datetime import datetime
from typing import Dict, Any, Tuple, Optional
from jsonschema import validate, ValidationError, draft7_format_checker
import colorama
from colorama import Fore, Style

# Initialize colorama for cross-platform colored output
colorama.init()

class SchemaValidator:
    """
    A robust schema validator for JSON log entries.
    
    Think of this class as a quality control inspector in a factory.
    Every product (log entry) must meet specific standards (schema)
    before it can proceed down the assembly line (to storage/processing).
    """
    
    def __init__(self, schema_directory: str = "schemas"):
        """
        Initialize the validator with schemas from the specified directory.
        
        Args:
            schema_directory: Path to directory containing JSON schema files
        """
        self.schema_directory = schema_directory
        self.schemas = {}
        self.validation_stats = {
            'total_validated': 0,
            'valid_count': 0,
            'invalid_count': 0,
            'error_types': {}
        }
        
        # Load all schema files at startup for better performance
        self._load_schemas()
    
    def _load_schemas(self) -> None:
        """
        Load all JSON schema files from the schema directory.
        
        This method runs once during initialization to avoid file I/O
        during high-throughput validation operations.
        """
        if not os.path.exists(self.schema_directory):
            print(f"{Fore.YELLOW}Warning: Schema directory '{self.schema_directory}' not found{Style.RESET_ALL}")
            return
        
        for filename in os.listdir(self.schema_directory):
            if filename.endswith('.json'):
                schema_name = filename.replace('.json', '')
                schema_path = os.path.join(self.schema_directory, filename)
                
                try:
                    with open(schema_path, 'r') as file:
                        self.schemas[schema_name] = json.load(file)
                    print(f"{Fore.GREEN}✓ Loaded schema: {schema_name}{Style.RESET_ALL}")
                except Exception as e:
                    print(f"{Fore.RED}✗ Failed to load schema {filename}: {e}{Style.RESET_ALL}")
    
    def validate_log(self, log_data: Dict[Any, Any], schema_name: str = "log_schema") -> Tuple[bool, Optional[str]]:
        """
        Validate a single log entry against the specified schema.
        
        Args:
            log_data: The JSON log data to validate
            schema_name: Name of the schema to validate against
            
        Returns:
            Tuple of (is_valid, error_message)
            
        Think of this method as a checkpoint scanner. Each log must pass
        through this checkpoint and receive approval before proceeding.
        """
        self.validation_stats['total_validated'] += 1
        
        # Check if the requested schema exists
        if schema_name not in self.schemas:
            error_msg = f"Schema '{schema_name}' not found"
            self._record_error("schema_not_found")
            return False, error_msg
        
        try:
            # Perform the actual validation using jsonschema library
            # This is like having an expert inspector check every detail
            validate(
                instance=log_data,
                schema=self.schemas[schema_name],
                format_checker=draft7_format_checker  # Validates formats like date-time, email, etc.
            )
            
            # If we reach here, validation succeeded
            self.validation_stats['valid_count'] += 1
            return True, None
            
        except ValidationError as e:
            # Validation failed - record the specific error type
            error_type = self._categorize_validation_error(e)
            self._record_error(error_type)
            
            # Create a human-readable error message
            error_msg = f"Validation failed: {e.message}"
            return False, error_msg
            
        except Exception as e:
            # Unexpected error during validation
            self._record_error("unexpected_error")
            return False, f"Unexpected validation error: {str(e)}"
    
    def _categorize_validation_error(self, error: ValidationError) -> str:
        """
        Categorize validation errors for better monitoring and debugging.
        
        This helps us understand what types of invalid data we're receiving,
        similar to how a factory tracks different types of defects.
        """
        if "required" in error.message.lower():
            return "missing_required_field"
        elif "format" in error.message.lower():
            return "invalid_format"
        elif "type" in error.message.lower():
            return "wrong_data_type"
        elif "enum" in error.message.lower():
            return "invalid_enum_value"
        else:
            return "other_validation_error"
    
    def _record_error(self, error_type: str) -> None:
        """Record error statistics for monitoring and debugging."""
        self.validation_stats['invalid_count'] += 1
        self.validation_stats['error_types'][error_type] = \
            self.validation_stats['error_types'].get(error_type, 0) + 1
    
    def get_validation_stats(self) -> Dict[str, Any]:
        """
        Return current validation statistics.
        
        This is like a factory's quality control dashboard showing
        how many products passed vs failed inspection.
        """
        total = self.validation_stats['total_validated']
        if total > 0:
            success_rate = (self.validation_stats['valid_count'] / total) * 100
        else:
            success_rate = 0
            
        return {
            **self.validation_stats,
            'success_rate_percent': round(success_rate, 2)
        }
    
    def enrich_log(self, log_data: Dict[Any, Any]) -> Dict[Any, Any]:
        """
        Add system-generated fields to enhance log usefulness.
        
        This is like adding quality control stamps and tracking numbers
        to products as they move through our system.
        """
        enriched_log = log_data.copy()
        
        # Add processing timestamp if not present
        if 'processed_at' not in enriched_log:
            enriched_log['processed_at'] = datetime.utcnow().isoformat()
        
        # Add validation status
        enriched_log['validation_status'] = 'passed'
        
        # Add system metadata
        if 'metadata' not in enriched_log:
            enriched_log['metadata'] = {}
        
        enriched_log['metadata']['processor_version'] = '1.0.0'
        enriched_log['metadata']['validation_timestamp'] = datetime.utcnow().isoformat()
        
        return enriched_log