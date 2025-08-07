import pytest
import tempfile
from pathlib import Path
from click.testing import CliRunner

from logplatform_cli.main import cli

class TestCLIIntegration:
    
    def test_cli_version(self):
        """Test CLI version command"""
        runner = CliRunner()
        result = runner.invoke(cli, ['--version'])
        assert result.exit_code == 0
        assert '1.0.0' in result.output
    
    def test_config_commands(self):
        """Test config get/set commands"""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Override home directory
            original_home = Path.home
            Path.home = lambda: Path(temp_dir)
            
            try:
                runner = CliRunner()
                
                # Test set command
                result = runner.invoke(cli, ['config', 'set', 'test_key', 'test_value'])
                assert result.exit_code == 0
                
                # Test get command
                result = runner.invoke(cli, ['config', 'get', 'test_key'])
                assert result.exit_code == 0
                assert 'test_value' in result.output
                
            finally:
                Path.home = original_home
    
    def test_help_commands(self):
        """Test help output for various commands"""
        runner = CliRunner()
        
        # Test main help
        result = runner.invoke(cli, ['--help'])
        assert result.exit_code == 0
        assert 'LogPlatform CLI' in result.output
        
        # Test auth help
        result = runner.invoke(cli, ['auth', '--help'])
        assert result.exit_code == 0
        assert 'Authentication management' in result.output
        
        # Test logs help
        result = runner.invoke(cli, ['logs', '--help'])
        assert result.exit_code == 0
        assert 'Log management' in result.output
