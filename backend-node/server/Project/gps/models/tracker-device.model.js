'use strict';

const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  deviceId: { type: String, required: true, unique: true, trim: true },
  name: { type: String, default: null, trim: true },
  guardId: { type: String, default: null, trim: true },
  status: { type: String, default: 'offline' },
  lastSeenAt: { type: Date, default: null },
  lastCoordinates: {
    latitude: { type: Number, default: null },
    longitude: { type: Number, default: null }
  },
  metadata: { type: mongoose.Schema.Types.Mixed, default: {} }
}, { timestamps: true });

module.exports = mongoose.model('GpsTrackerDevice', schema);
