int main(void)
{
  double T, a, b, N, p, V;
  double k;
  double res;

  T = __BUILTIN_DAED_DBETWEEN_WITH_ULP(300.0, 300.0);
  a = __BUILTIN_DAED_DBETWEEN_WITH_ULP(0.401, 0.401);
  b = __BUILTIN_DAED_DBETWEEN_WITH_ULP(42.7e-6, 42.7e-6);
  N = __BUILTIN_DAED_DBETWEEN_WITH_ULP(1000.0, 1000.0);
  p = __BUILTIN_DAED_DBETWEEN_WITH_ULP(3.5e7, 3.5e7);
  V = __BUILTIN_DAED_DBETWEEN_WITH_ULP(0.1, 0.5);

  k = 1.3806503e-23;
  res = (p + a * (N / V) * (N / V)) * (V - N * b) - k * N * T;
  DSENSITIVITY(res);

  return 0;
}
