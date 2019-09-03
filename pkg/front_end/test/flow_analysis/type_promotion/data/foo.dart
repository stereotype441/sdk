main() {
  for (int i = 0; i < 20; i++) {
    var timer = new Stopwatch();
    timer.start();
    List<int> primes = findPrimes(1000000);
    timer.stop();
    print('[$i] ${timer.elapsedMilliseconds} ms.');
    primes; // print?
  }
}

List<int> findPrimes(int last) {
  List<int> primes = [];
  for (int x = 2; x < last; x++) {
    bool isPrime = true;
    for (int i = 0; i < primes.length; i++) {
      int p = primes[i];
      if (p * p > x) {
        break;
      }
      if (x % p == 0) {
        isPrime = false;
        break;
      }
    }
    if (isPrime) {
      primes.add(x);
    }
  }
  return primes;
}
