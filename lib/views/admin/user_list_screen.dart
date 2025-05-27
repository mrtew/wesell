import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../models/user_model.dart';

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUsers();
    });
    // Add listener to search field
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Debounce search input
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Update search term in provider
      ref.read(pendingVerificationUsersProvider.notifier).updateSearchQuery(_searchController.text);
    });
  }
  
  // Refresh the user list
  Future<void> _refreshUsers() async {
    await ref.read(pendingVerificationUsersProvider.notifier).fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () {
            GoRouter.of(context).pop();
            ref.read(pendingVerificationUsersProvider.notifier).updateSearchQuery('');
          },
        ),
        title: Text(
          'Pending Verifications',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by username',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            
            // User list
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshUsers,
                child: Consumer(
                  builder: (context, ref, child) {
                    final usersAsync = ref.watch(pendingVerificationUsersProvider);
                    
                    return usersAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stackTrace) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: $error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refreshUsers,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                      data: (users) {
                        if (users.isEmpty) {
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.person_search, size: 64, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text(
                                          'No user found.',
                                          style: TextStyle(fontSize: 16, color: Colors.grey),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                        
                        return ListView.builder(
                          physics: AlwaysScrollableScrollPhysics(),
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            return _UserCard(
                              user: user,
                              onTap: () {
                                GoRouter.of(context).push('/admin/verify/${user.uid}');
                              }
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  
  const _UserCard({required this.user, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // onTap: () => GoRouter.of(context).push('/admin/verify/${user.uid}'),
      // onTap: () {
      //   GoRouter.of(context).push('/admin/verify/${user.uid}');
      //   ref.read(pendingVerificationUsersProvider.notifier).updateSearchQuery('');
      // },
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // User avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: user.avatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: user.avatar,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.person, color: Colors.grey),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error, color: Colors.red),
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.person, color: Colors.grey),
                      ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // User details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username.isEmpty ? 'No Username' : user.username,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.phoneNumber,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}