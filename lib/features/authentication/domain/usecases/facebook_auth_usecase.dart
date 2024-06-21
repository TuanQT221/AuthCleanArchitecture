import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failures.dart';
import '../repositories/authentication_repository.dart';

class FacebookAuthUseCase {
  final AuthenticationRepository repository;

  FacebookAuthUseCase(this.repository);

  Future<Either<Failure, UserCredential>> call() async {
    return await repository.facebookSignIn();
  }
}
