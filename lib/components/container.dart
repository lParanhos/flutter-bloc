import 'package:flutter/material.dart';

abstract class BlocContainer extends StatelessWidget {}

void push(BuildContext blockContext, BlocContainer container) {
  Navigator.of(blockContext).push(
    MaterialPageRoute(
      builder: (context) => container,
    ),
  );
}
