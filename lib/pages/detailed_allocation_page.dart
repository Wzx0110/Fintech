import 'package:flutter/material.dart';

class DetailedAllocationPage extends StatelessWidget {
  final String title;
  final List<MapEntry<String, double>> allocationData;
  final List<Color> colors;

  const DetailedAllocationPage({
    super.key,
    required this.title,
    required this.allocationData,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: allocationData.isEmpty
          ? const Center(child: Text('沒有詳細數據可顯示'))
          : ListView.separated(
              itemCount: allocationData.length,
              itemBuilder: (context, index) {
                final entry = allocationData[index];
                final label = entry.key;
                final percentage = entry.value;
                final color = colors.isNotEmpty && index < colors.length
                    ? colors[index]
                    : Colors.grey;

                if (percentage < 0.01 && label != '其他股票' && label != '其他產業') {
                  return const SizedBox.shrink();
                }

                return ListTile(
                  leading: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                  title: Text(label, style: Theme.of(context).textTheme.titleMedium),
                  trailing: Text(
                    '${percentage.toStringAsFixed(2)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                );
              },
              separatorBuilder: (context, index) => const Divider(height: 1),
            ),
    );
  }
}