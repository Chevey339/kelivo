/// Whole minutes, with zero meaning periodic refresh is disabled.
bool isBalanceRefreshInterval(Object? value) =>
    value is int && value >= 0 && value <= 0x7fffffff;
