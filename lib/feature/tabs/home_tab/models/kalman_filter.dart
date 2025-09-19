class KalmanFilter {
  double _estimate;
  double _error;
  final double _q;
  final double _r;

  KalmanFilter(double initialValue, {double q = 0.01, double r = 3})
      : _estimate = initialValue,
        _error = 1,
        _q = q,
        _r = r;

  double filter(double measurement) {
    _error += _q;
    final kalmanGain = _error / (_error + _r);
    _estimate = _estimate + kalmanGain * (measurement - _estimate);
    _error = (1 - kalmanGain) * _error;

    return _estimate;
  }
}
