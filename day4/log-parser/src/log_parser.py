class LogParser:
   def __init__(self):
       # Dictionary to store different parser implementations
       self.parsers = {
           'apache': self.parse_apache_log,
           'nginx': self.parse_nginx_log,
           'json': self.parse_json_log
       }
       
   def detect_format(self, log_line):
       """Detect the format of a log line"""
       import json
       import re
       
       # Try to parse as JSON
       try:
           json.loads(log_line)
           return 'json'
       except ValueError:
           pass
       
       # Check for Apache/Nginx patterns
       apache_pattern = r'\S+ - - \[\d+/\w+/\d+:\d+:\d+:\d+ [\+\-]\d+\]'
       nginx_pattern = r'\S+ - \S+ \[\d+/\w+/\d+:\d+:\d+:\d+ [\+\-]\d+\]'
       
       if re.match(apache_pattern, log_line):
           return 'apache'
       elif re.match(nginx_pattern, log_line):
           return 'nginx'
       
       return 'unknown'
   
   def parse(self, log_line):
       """Parse a log line into structured data"""
       log_format = self.detect_format(log_line)
       
       if log_format in self.parsers:
           return self.parsers[log_format](log_line)
       else:
           return {'raw': log_line, 'format': 'unknown'}
   
   def parse_apache_log(self, log_line):
       """Parse Apache common log format"""
       import re
       pattern = r'(\S+) - - \[(\d+/\w+/\d+):(\d+:\d+:\d+) ([\+\-]\d+)\] "(\S+) (\S+) ([^"]+)" (\d+) (\d+|-)'
       match = re.match(pattern, log_line)
       
       if match:
           ip, date, time, timezone, method, path, protocol, status, size = match.groups()
           
           try:
               status_code = int(status)
               size = int(size) if size != '-' else 0
           except ValueError:
               status_code = 0
               size = 0
               
           # Convert Apache date format to ISO format
           from datetime import datetime
           try:
               dt = datetime.strptime(f"{date}:{time} {timezone}", "%d/%b/%Y:%H:%M:%S %z")
               timestamp = dt.isoformat()
           except ValueError:
               timestamp = f"{date}T{time}{timezone}"
               
           return {
               'timestamp': timestamp,
               'source_ip': ip,
               'method': method,
               'path': path,
               'protocol': protocol,
               'status_code': status_code,
               'size': size,
               'format': 'apache'
           }
       
       return {'raw': log_line, 'format': 'unknown'}
   
   def parse_nginx_log(self, log_line):
       """Parse Nginx access log format"""
       import re
       pattern = r'(\S+) - (\S+) \[(\d+/\w+/\d+):(\d+:\d+:\d+) ([\+\-]\d+)\] "(\S+) (\S+) ([^"]+)" (\d+) (\d+) "([^"]*)" "([^"]*)"'
       match = re.match(pattern, log_line)
       
       if match:
           ip, user, date, time, timezone, method, path, protocol, status, size, referrer, user_agent = match.groups()
           
           try:
               status_code = int(status)
               size = int(size)
           except ValueError:
               status_code = 0
               size = 0
               
           # Convert Nginx date format to ISO format
           from datetime import datetime
           try:
               dt = datetime.strptime(f"{date}:{time} {timezone}", "%d/%b/%Y:%H:%M:%S %z")
               timestamp = dt.isoformat()
           except ValueError:
               timestamp = f"{date}T{time}{timezone}"
               
           return {
               'timestamp': timestamp,
               'source_ip': ip,
               'user': user if user != '-' else None,
               'method': method,
               'path': path,
               'protocol': protocol,
               'status_code': status_code,
               'size': size,
               'referrer': referrer if referrer != '-' else None,
               'user_agent': user_agent,
               'format': 'nginx'
           }
       
       return {'raw': log_line, 'format': 'unknown'}
   
   def parse_json_log(self, log_line):
       """Parse JSON log format"""
       import json
       try:
           data = json.loads(log_line)
           
           # Add standard format indicator
           data['format'] = 'json'
           
           # Map common fields to our schema if they exist with different names
           field_mappings = {
               'ip': 'source_ip',
               'level': 'log_level',
               'msg': 'message',
               'time': 'timestamp'
           }
           
           for src, dst in field_mappings.items():
               if src in data and dst not in data:
                   data[dst] = data[src]
                   
           return data
       except json.JSONDecodeError:
           return {'raw': log_line, 'format': 'unknown'}
