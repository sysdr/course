import React from 'react';
import './StreamSelector.css';

const StreamSelector = ({ streams, selectedStream, onStreamChange, disabled }) => {
  return (
    <div className="stream-selector">
      <label htmlFor="stream-select">Stream:</label>
      <select
        id="stream-select"
        value={selectedStream}
        onChange={(e) => onStreamChange(e.target.value)}
        disabled={disabled}
        className="form-control"
      >
        {streams.map(stream => (
          <option key={stream.id} value={stream.id}>
            {stream.name} {stream.active ? '🟢' : '🔴'}
          </option>
        ))}
      </select>
      {disabled && (
        <span className="disabled-hint">Disconnect to change stream</span>
      )}
    </div>
  );
};

export default StreamSelector;
