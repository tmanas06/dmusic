import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:crypto/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  String? _derivedAddress;
  EthPrivateKey? _derivedCredentials;
  double _balance = 0;
  int _totalPredictions = 0;
  bool _isLoading = false;
  bool _isFetchingBalance = false;

  User? get user => _user;
  String? get derivedAddress => _derivedAddress;
  double get balance => _balance;
  int get totalPredictions => _totalPredictions;
  bool get isLoading => _isLoading;
  bool get isFetchingBalance => _isFetchingBalance;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _deriveWallet(user.uid);
      } else {
        _derivedAddress = null;
        _derivedCredentials = null;
      }
      notifyListeners();
    });
  }

  void _deriveWallet(String uid) {
    final bytes = utf8.encode('$uid wave_salt_v1_2026');
    final hash = sha256.convert(bytes);
    try {
      _derivedCredentials = EthPrivateKey.fromHex(hash.toString());
      _derivedAddress = _derivedCredentials!.address.hex;
      fetchBalance(); // Refresh balance after derivation
    } catch (e) {
      debugPrint('[wave] Wallet Derivation Error: $e');
    }
  }

  Future<void> fetchBalance() async {
    if (_derivedAddress == null) return;
    
    _isFetchingBalance = true;
    notifyListeners();
    
    try {
      final client = Web3Client('https://testnet-rpc.monad.xyz', Client());
      final address = EthereumAddress.fromHex(_derivedAddress!);
      final balanceValue = await client.getBalance(address);
      _balance = balanceValue.getValueInUnit(EtherUnit.ether);
      await client.dispose();
    } catch (e) {
      debugPrint('[wave] Balance Fetch Error: $e');
    } finally {
      _isFetchingBalance = false;
      notifyListeners();
    }
  }

  Future<String?> sendBet(String trackId, bool isBanger) async {
    if (_derivedCredentials == null) return null;

    try {
      final client = Web3Client('https://testnet-rpc.monad.xyz', Client());
      
      final String toAddress = '0x742d35Cc6634C0532925a3b844Bc454e4438f44e';
      
      // Send 0.01 MON from the derived social wallet
      final response = await client.sendTransaction(
        _derivedCredentials!,
        Transaction(
          to: EthereumAddress.fromHex(toAddress),
          value: EtherAmount.fromBigInt(EtherUnit.wei, BigInt.parse('10000000000000000')), // 0.01 MON
          maxGas: 100000,
        ),
        chainId: 10143,
      );

      await client.dispose();
      _totalPredictions++;
      notifyListeners();
      fetchBalance(); // Refresh balance after bet
      return response;
    } catch (e) {
      debugPrint('[wave] Auth Wallet Bet Error: $e');
      return null;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[wave] Google Sign-In Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
