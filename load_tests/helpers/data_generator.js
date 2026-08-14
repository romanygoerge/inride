// load_tests/helpers/data_generator.js

/**
 * Dynamic data generator for k6 virtual users
 */

export function getRandomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

export function getRandomFloat(min, max, decimals = 6) {
  const str = (Math.random() * (max - min) + min).toFixed(decimals);
  return parseFloat(str);
}

export function getRandomUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

export function getRandomPhoneNumber() {
  const prefix = '+2010';
  const digits = Math.floor(10000000 + Math.random() * 90000000);
  return `${prefix}${digits}`;
}

export function getRandomEmail(role = 'user') {
  const ts = Date.now();
  const rand = Math.floor(Math.random() * 100000);
  return `loadtest_${role}_${ts}_${rand}@inride-test.com`;
}

// Center point: Cairo Coordinates (30.0444, 31.2357)
export function getRandomLocation() {
  const latOffset = (Math.random() - 0.5) * 0.1; // ~10km radius
  const lngOffset = (Math.random() - 0.5) * 0.1;
  return {
    latitude: 30.0444 + latOffset,
    longitude: 31.2357 + lngOffset,
  };
}

export function getRandomFare() {
  return getRandomFloat(25.0, 150.0, 2);
}

export function getRandomVehicleType() {
  const types = ['car', 'motorcycle', 'comfort', 'scooter'];
  return types[getRandomInt(0, types.length - 1)];
}
