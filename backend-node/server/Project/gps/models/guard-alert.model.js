'use strict';

const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  guardId: { type: String, required: true, trim: true },
  title: { type: String, required: true, trim: true },
  description: { type: String, default: null, trim: true },
  severity: { type: String, default: 'medium' },
  status: { type: String, default: 'open' }
}, { timestamps: true });

module.exports = mongoose.model('GpsGuardAlert', schema);
