import 'dart:async';

import 'package:authentication/features/authentication/domain/entities/sign_in_entity.dart';
import 'package:authentication/features/authentication/domain/entities/sign_up_entity.dart';
import 'package:authentication/features/authentication/domain/usecases/facebook_auth_usecase.dart'; // New import
import 'package:authentication/features/authentication/domain/usecases/first_page_usecase.dart';
import 'package:authentication/features/authentication/domain/usecases/google_auth_usecase.dart';
import 'package:authentication/features/authentication/domain/usecases/logout_usecase.dart';
import 'package:authentication/features/authentication/domain/usecases/sign_in_usecase.dart';
import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/strings/failures.dart';
import '../../../domain/usecases/check_verification_usecase.dart';
import '../../../domain/usecases/sign_up_usecase.dart';
import '../../../domain/usecases/verifiy_email_usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignInUseCase signInUseCase;
  final SignUpUseCase signUpUseCase;
  final VerifyEmailUseCase verifyEmailUseCase;
  final FirstPageUseCase firstPage;
  final CheckVerificationUseCase checkVerificationUseCase;
  final LogOutUseCase logOutUseCase;
  final GoogleAuthUseCase googleAuthUseCase;
  final FacebookAuthUseCase facebookAuthUseCase; // New use case

  Completer<void> completer = Completer<void>();

  AuthBloc({
    required this.signInUseCase,
    required this.signUpUseCase,
    required this.firstPage,
    required this.verifyEmailUseCase,
    required this.checkVerificationUseCase,
    required this.logOutUseCase,
    required this.googleAuthUseCase,
    required this.facebookAuthUseCase, // New use case
  }) : super(AuthInitial()) {
    on<AuthEvent>(_onEvent);
  }

  void _onEvent(AuthEvent event, Emitter<AuthState> emit) async {
    final eventHandlers =
        <Type, Future<void> Function(AuthEvent, Emitter<AuthState>)>{
      CheckLoggingInEvent: _handleCheckLoggingInEvent,
      SignInEvent: _handleSignInEvent,
      SignUpEvent: _handleSignUpEvent,
      SendEmailVerificationEvent: _handleSendEmailVerificationEvent,
      CheckEmailVerificationEvent: _handleCheckEmailVerificationEvent,
      LogOutEvent: _handleLogOutEvent,
      SignInWithGoogleEvent: _handleSignInWithGoogleEvent,
      SignInWithFacebookEvent: _handleSignInWithFacebookEvent, // New event
    };

    final handler = eventHandlers[event.runtimeType];
    if (handler != null) {
      await handler(event, emit);
    }
  }

  Future<void> _handleCheckLoggingInEvent(
      AuthEvent event, Emitter<AuthState> emit) async {
    final theFirstPage = firstPage();
    if (theFirstPage.isLoggedIn) {
      emit(SignedInPageState());
    } else if (theFirstPage.isVerifyingEmail) {
      emit(VerifyEmailPageState());
    }
  }

  Future<void> _handleSignInEvent(
      AuthEvent event, Emitter<AuthState> emit) async {
    emit(LoadingState());
    final failureOrUserCredential =
        await signInUseCase((event as SignInEvent).signInEntity);
    emit(eitherToState(failureOrUserCredential, SignedInState()));
  }

  Future<void> _handleSignUpEvent(
      AuthEvent event, Emitter<AuthState> emit) async {
    emit(LoadingState());
    final failureOrUserCredential =
        await signUpUseCase((event as SignUpEvent).signUpEntity);
    emit(eitherToState(failureOrUserCredential, SignedUpState()));
  }

  Future<void> _handleSendEmailVerificationEvent(
      AuthEvent event, Emitter<AuthState> emit) async {
    final failureOrSentEmail = await verifyEmailUseCase();
    emit(eitherToState(failureOrSentEmail, EmailIsSentState()));
  }

  Future<void> _handleCheckEmailVerificationEvent(
      AuthEvent event, Emitter<AuthState> emit) async {
    if (!completer.isCompleted) {
      completer.complete();
      completer = Completer<void>();
    }
    final failureOrEmailVerified = await checkVerificationUseCase(completer);
    emit(eitherToState(failureOrEmailVerified, EmailIsVerifiedState()));
  }

  Future<void> _handleLogOutEvent(
      AuthEvent event, Emitter<AuthState> emit) async {
    final failureOrLogOut = await logOutUseCase();
    emit(eitherToState(failureOrLogOut, LoggedOutState()));
  }

  Future<void> _handleSignInWithGoogleEvent(
      AuthEvent event, Emitter<AuthState> emit) async {
    emit(LoadingState());
    final failureOrUserCredential = await googleAuthUseCase();
    emit(eitherToState(failureOrUserCredential, GoogleSignInState()));
  }

  Future<void> _handleSignInWithFacebookEvent(
      AuthEvent event, Emitter<AuthState> emit) async {
    emit(LoadingState());
    final failureOrUserCredential = await facebookAuthUseCase();
    emit(eitherToState(
        failureOrUserCredential, FacebookSignInState())); // New state
  }

  AuthState eitherToState(Either either, AuthState state) {
    return either.fold(
      (failure) => ErrorAuthState(message: _mapFailureToMessage(failure)),
      (_) => state,
    );
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return SERVER_FAILURE_MESSAGE;
      case OfflineFailure:
        return OFFLINE_FAILURE_MESSAGE;
      case WeekPassFailure:
        return WEEK_PASS_FAILURE_MESSAGE;
      case ExistedAccountFailure:
        return EXISTED_ACCOUNT_FAILURE_MESSAGE;
      case NoUserFailure:
        return NO_USER_FAILURE_MESSAGE;
      case TooManyRequestsFailure:
        return TOO_MANY_REQUESTS_FAILURE_MESSAGE;
      case WrongPasswordFailure:
        return WRONG_PASSWORD_FAILURE_MESSAGE;
      case UnmatchedPassFailure:
        return UNMATCHED_PASSWORD_FAILURE_MESSAGE;
      case NotLoggedInFailure:
        return '';
      default:
        return "Unexpected Error, Please try again later.";
    }
  }
}
