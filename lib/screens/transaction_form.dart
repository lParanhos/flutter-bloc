import 'dart:async';

import 'package:bytebank/components/container.dart';
import 'package:bytebank/components/error.dart';
import 'package:bytebank/components/progress.dart';
import 'package:bytebank/components/transaction_auth_dialog.dart';
import 'package:bytebank/http/webclients/transaction_webclient.dart';
import 'package:bytebank/models/contact.dart';
import 'package:bytebank/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

@immutable
abstract class TransactionFormState {
  const TransactionFormState();
}

@immutable
class SendingTransactionFormState extends TransactionFormState {
  const SendingTransactionFormState();
}

@immutable
class ShowTransactionFormState extends TransactionFormState {
  const ShowTransactionFormState();
}

@immutable
class SentTransactionFormState extends TransactionFormState {
  const SentTransactionFormState();
}

@immutable
class FatalErrorTransactionFormState extends TransactionFormState {
  final String _message;
  const FatalErrorTransactionFormState(this._message);
}

class TransactionFormCubit extends Cubit<TransactionFormState> {
  TransactionFormCubit() : super(ShowTransactionFormState());

  void save(Transaction transactionCreated, String password,
      BuildContext context) async {
    emit(SendingTransactionFormState());
    await _send(
      transactionCreated,
      password,
      context,
    );
  }

  _send(Transaction transactionCreated, String password,
      BuildContext context) async {
    await TransactionWebClient()
        .save(transactionCreated, password)
        .then((trasaction) => emit(SentTransactionFormState()))
        .catchError((e) {
      emit(FatalErrorTransactionFormState(e.message));
    }, test: (e) => e is HttpException).catchError((e) {
      emit(
          FatalErrorTransactionFormState('timeout submitting the transaction'));
    }, test: (e) => e is TimeoutException).catchError((e) {
      emit(FatalErrorTransactionFormState(e.message));
    });
  }
}

class TransactionFormContainer extends BlocContainer {
  final Contact _contact;
  TransactionFormContainer(this._contact);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TransactionFormCubit>(
      create: (context) {
        return TransactionFormCubit();
      },
      child: BlocListener<TransactionFormCubit, TransactionFormState>(
        listener: (context, state) {
          if (state is SentTransactionFormState) {
            Navigator.pop(context);
          }
        },
        child: TransactionForm(_contact),
      ),
    );
  }
}

class TransactionForm extends StatelessWidget {
  final Contact contact;
  TransactionForm(this.contact);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionFormCubit, TransactionFormState>(
        builder: (context, state) {
      if (state is ShowTransactionFormState) {
        return _BasicForm(contact);
      }

      if (state is SendingTransactionFormState ||
          state is SentTransactionFormState) {
        return ProgressView();
      }

      if (state is FatalErrorTransactionFormState) {
        return ErrorView(state._message);
      }

      return ErrorView('Unknown error');
    });
    //return _BasicForm();
  }
}

class _BasicForm extends StatelessWidget {
  final Contact contact;
  final TextEditingController _valueController = TextEditingController();
  final String transactionId = Uuid().v4();

  _BasicForm(this.contact);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New transaction'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                contact.name,
                style: TextStyle(
                  fontSize: 24.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  contact.accountNumber.toString(),
                  style: TextStyle(
                    fontSize: 32.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextField(
                  controller: _valueController,
                  style: TextStyle(fontSize: 24.0),
                  decoration: InputDecoration(labelText: 'Value'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: SizedBox(
                  width: double.maxFinite,
                  child: RaisedButton(
                    child: Text('Transfer'),
                    onPressed: () {
                      final double value =
                          double.tryParse(_valueController.text);
                      final transactionCreated = Transaction(
                        transactionId,
                        value,
                        contact,
                      );
                      showDialog(
                          context: context,
                          builder: (contextDialog) {
                            return TransactionAuthDialog(
                              onConfirm: (String password) {
                                BlocProvider.of<TransactionFormCubit>(context)
                                    .save(
                                        transactionCreated, password, context);
                              },
                            );
                          });
                    },
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
