import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aed_map/bloc/search/search_cubit.dart';
import 'package:aed_map/generated/i18n/app_localizations.dart';

class SearchDialog extends StatefulWidget {
  const SearchDialog({super.key});

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var appLocalizations = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CupertinoSearchTextField(
              controller: _controller,
              autofocus: true,
              placeholder: appLocalizations.searchLocationPlaceholder,
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  context.read<SearchCubit>().search(value, appLocalizations.localeName);
                });
              },
              onSubmitted: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                context.read<SearchCubit>().search(value, appLocalizations.localeName);
              },
              onSuffixTap: () {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _controller.clear();
                context.read<SearchCubit>().clear();
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<SearchCubit, SearchState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                if (state.error.isNotEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        state.error,
                        style: TextStyle(
                            color: CupertinoColors.systemRed.resolveFrom(context)),
                      ),
                    ),
                  );
                }

                if (state.results.isEmpty) {
                  return Center(
                    child: Text(
                      appLocalizations.searchNoResults,
                      style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: state.results.length,
                  itemBuilder: (context, index) {
                    final result = state.results[index];
                    return CupertinoListTile(
                      title: Text(result.name),
                      subtitle: Text(
                        result.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      leading: const Icon(CupertinoIcons.location),
                      onTap: () {
                        context.read<SearchCubit>().selectLocation(result.location);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
