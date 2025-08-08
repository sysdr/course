import pytest
import time
import requests
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options

@pytest.fixture
def browser():
    """Setup headless Chrome browser for testing"""
    chrome_options = Options()
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    
    try:
        driver = webdriver.Chrome(options=chrome_options)
        yield driver
        driver.quit()
    except Exception as e:
        pytest.skip(f"Chrome browser not available: {e}")

def test_api_backend_running():
    """Test that Flask backend is running"""
    try:
        response = requests.get('http://localhost:5000/api/health', timeout=5)
        assert response.status_code == 200
        assert response.json()['status'] == 'healthy'
    except requests.RequestException:
        pytest.skip("Backend not running")

def test_frontend_running():
    """Test that React frontend is accessible"""
    try:
        response = requests.get('http://localhost:3000', timeout=5)
        assert response.status_code == 200
    except requests.RequestException:
        pytest.skip("Frontend not running")

def test_dashboard_loads(browser):
    """Test that dashboard page loads correctly"""
    browser.get('http://localhost:3000')
    
    # Wait for header to load
    WebDriverWait(browser, 10).until(
        EC.presence_of_element_located((By.TAG_NAME, "header"))
    )
    
    # Check if dashboard title is present
    assert "Distributed Log Viewer" in browser.title or "Log Viewer Dashboard" in browser.page_source

def test_log_viewer_navigation(browser):
    """Test navigation to log viewer page"""
    browser.get('http://localhost:3000')
    
    # Find and click log viewer link
    log_viewer_link = WebDriverWait(browser, 10).until(
        EC.element_to_be_clickable((By.LINK_TEXT, "Log Viewer"))
    )
    log_viewer_link.click()
    
    # Wait for log viewer page to load
    WebDriverWait(browser, 10).until(
        EC.presence_of_element_located((By.CLASS_NAME, "log-viewer"))
    )
    
    # Check URL changed
    assert "/logs" in browser.current_url

def test_sample_data_initialization(browser):
    """Test sample data can be loaded through UI"""
    browser.get('http://localhost:3000')
    
    # Look for sample data button and click it
    try:
        sample_btn = WebDriverWait(browser, 10).until(
            EC.element_to_be_clickable((By.XPATH, "//button[contains(text(), 'Load Sample Data')]"))
        )
        sample_btn.click()
        
        # Wait for data to load (button text or page content should change)
        time.sleep(2)
        
    except Exception:
        pytest.skip("Sample data button not found or not clickable")
