import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class RatingsListSkeleton extends StatelessWidget {
  const RatingsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SkeletonPlaceholder(width: 36, height: 36, borderRadius: 18),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonPlaceholder(width: 80, height: 12),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(
                          5,
                          (i) => const Padding(
                            padding: EdgeInsets.only(right: 2.0),
                            child: SkeletonPlaceholder(width: 12, height: 12, borderRadius: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SkeletonPlaceholder(width: 60, height: 10),
                ],
              ),
              const SizedBox(height: 12),
              const SkeletonPlaceholder(width: double.infinity, height: 10),
              const SizedBox(height: 6),
              const SkeletonPlaceholder(width: 150, height: 10),
            ],
          ),
        );
      },
    );
  }
}

class HistoryListSkeleton extends StatelessWidget {
  const HistoryListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SkeletonPlaceholder(width: 120, height: 14),
                  const SkeletonPlaceholder(width: 60, height: 14, borderRadius: 8),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                      Container(width: 2, height: 20, color: Colors.grey[200]),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonPlaceholder(width: 160, height: 12),
                        SizedBox(height: 14),
                        SkeletonPlaceholder(width: 200, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SkeletonPlaceholder(width: 80, height: 16),
                  const SkeletonPlaceholder(width: 80, height: 16),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class TransactionsListSkeleton extends StatelessWidget {
  const TransactionsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200] ?? Colors.grey),
          ),
          child: Row(
            children: [
              const SkeletonPlaceholder(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonPlaceholder(width: 100, height: 12),
                    const SizedBox(height: 6),
                    const SkeletonPlaceholder(width: 140, height: 10),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SkeletonPlaceholder(width: 60, height: 14),
            ],
          ),
        );
      },
    );
  }
}
