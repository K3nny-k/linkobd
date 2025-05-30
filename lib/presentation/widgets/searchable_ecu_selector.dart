import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/ecu/ecu_repository.dart';
import '../view_models/bluetooth_view_model.dart';

class SearchableEcuSelector extends StatefulWidget {
  const SearchableEcuSelector({super.key});

  @override
  State<SearchableEcuSelector> createState() => _SearchableEcuSelectorState();
}

class _SearchableEcuSelectorState extends State<SearchableEcuSelector> {
  final _fieldCtrl = TextEditingController();

  @override
  void dispose() {
    _fieldCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothViewModel>(
      builder: (context, vm, child) {
        // Reflect current selection in the field
        _fieldCtrl.text = vm.selectedEcu == null
            ? ''
            : '${vm.selectedEcu!.name} – ${vm.selectedEcu!.ecuId}';

        return TextField(
          controller: _fieldCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Select ECU',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.arrow_drop_down),
            prefixIcon: Icon(Icons.search),
          ),
          onTap: () => _openSheet(context, vm),
        );
      },
    );
  }

  Future<void> _openSheet(BuildContext ctx, BluetoothViewModel vm) async {
    final result = await showModalBottomSheet<EcuInfo>(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EcuSheet(list: vm.ecuList),
    );
    if (result != null) {
      vm.selectEcu(result);
    }
  }
}

class _EcuSheet extends StatefulWidget {
  final List<EcuInfo> list;
  
  const _EcuSheet({required this.list});

  @override
  State<_EcuSheet> createState() => _EcuSheetState();
}

class _EcuSheetState extends State<_EcuSheet> {
  late List<EcuInfo> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.list); // Start with full list
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Select ECU',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                
                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or ID...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _filter,
                    autofocus: true,
                  ),
                ),
                
                // ECU list
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('No device found'),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final ecu = _filtered[i];
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                                                 decoration: BoxDecoration(
                                   color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                   borderRadius: BorderRadius.circular(8),
                                 ),
                                child: Center(
                                  child: Text(
                                    ecu.node,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(ecu.name),
                              subtitle: Text('ID: ${ecu.ecuId}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pop(context, ecu),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _filter(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.from(widget.list);
      } else {
        _filtered = widget.list.where((ecu) {
          return ecu.name.toLowerCase().contains(lowerQuery) ||
                 ecu.ecuId.toLowerCase().contains(lowerQuery) ||
                 ecu.node.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }
} 