List<int> findPrimes(int last) {
  List<int> primes = [];
  for (int x = 2; x < last; x++) {
    bool isPrime = true; // KEEP?
    for (int i = 0; i < primes.length; i++) {
      int p = primes[i];
      if (p * p > x) { // KEEP?
        break; // KEEP?
      } // KEEP?
      if (x % p == 0) {
        isPrime = false; // KEEP?
      }
    }
  }
}
