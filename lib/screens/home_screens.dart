import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:adminoffacebookapp/reusable/customIcons.dart';
import 'package:adminoffacebookapp/reusable/custom_floating_action.dart';
import 'package:adminoffacebookapp/reusable/custom_sizedBox.dart';
import 'package:adminoffacebookapp/reusable/text_widgets.dart';

import '../consts/colors.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AccessToken? _accessToken;
  List<dynamic>? _userPages;
  List<dynamic> _allPageFeeds = [];
  bool _loadingPages = true;
  bool _loadingFeed = true;
  bool _loadingMore = false;
  String? _nextFeedUrl;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchUserPages();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent &&
          !_loadingMore) {
        _loadMoreFeeds();
      }
    });
  }

  Future<void> _fetchUserPages() async {
    setState(() {
      _loadingPages = true;
      _loadingFeed = true;
      _allPageFeeds.clear();
    });

    final accessToken = await FacebookAuth.instance.accessToken;
    if (accessToken != null) {
      final graphResponse = await http.get(
        Uri.parse('https://graph.facebook.com/v20.0/me/accounts'),
        headers: {
          'Authorization': 'Bearer ${accessToken.tokenString}',
          'Accept': 'application/json',
        },
      );

      if (graphResponse.statusCode == 200) {
        final jsonData = jsonDecode(graphResponse.body);
        setState(() {
          _userPages = jsonData['data'];
          _loadingPages = false;
        });
        if (_userPages != null && _userPages!.isNotEmpty) {
          for (var page in _userPages!) {
            final pageAccessToken = await _getPageAccessToken(page['id']);
            if (pageAccessToken != null) {
              await _fetchPageFeed(page['id'], pageAccessToken);
            }
          }
        }
      } else {
        print('Failed to fetch user pages: ${graphResponse.statusCode}');
        setState(() {
          _loadingPages = false;
        });
      }
    } else {
      print('Access token not found.');
      setState(() {
        _loadingPages = false;
      });
    }
  }

  Future<String?> _getPageAccessToken(String pageId) async {
    final accessToken = await FacebookAuth.instance.accessToken;
    if (accessToken != null) {
      final graphResponse = await http.get(
        Uri.parse(
            'https://graph.facebook.com/v20.0/$pageId?fields=access_token'),
        headers: {
          'Authorization': 'Bearer ${accessToken.tokenString}',
          'Accept': 'application/json',
        },
      );

      if (graphResponse.statusCode == 200) {
        final jsonData = jsonDecode(graphResponse.body);
        return jsonData['access_token'];
      } else {
        print('Failed to fetch page access token: ${graphResponse.statusCode}');
      }
    }
    return null;
  }

  Future<void> _fetchPageFeed(String pageId, String pageAccessToken,
      {bool isLoadMore = false}) async {
    final feedUrl = _nextFeedUrl ??
        'https://graph.facebook.com/v20.0/$pageId/feed?fields=message,full_picture,created_time,comments{message,from,created_time},likes.summary(true),shares&limit=10';
    final graphResponse = await http.get(
      Uri.parse(feedUrl),
      headers: {
        'Authorization': 'Bearer $pageAccessToken',
        'Accept': 'application/json',
      },
    );

    if (graphResponse.statusCode == 200) {
      final jsonData = jsonDecode(graphResponse.body);
      setState(() {
        _allPageFeeds.addAll(jsonData['data']);
        _nextFeedUrl = jsonData['paging']?['next'];
        _loadingFeed = false;
        _loadingMore = false;
      });
    } else {
      print('Failed to fetch page feed: ${graphResponse.statusCode}');
      setState(() {
        _loadingFeed = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMoreFeeds() async {
    if (_nextFeedUrl != null) {
      setState(() {
        _loadingMore = true;
      });

      final accessToken = await FacebookAuth.instance.accessToken;
      if (accessToken != null) {
        for (var page in _userPages!) {
          final pageAccessToken = await _getPageAccessToken(page['id']);
          if (pageAccessToken != null) {
            await _fetchPageFeed(page['id'], pageAccessToken, isLoadMore: true);
          }
        }
      }
    }
  }

  void _showPostDialog(BuildContext context) {
    final TextEditingController _postController = TextEditingController();
    File? _imageFile;

    Future<void> _pickImage() async {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: primaryTextColor,
              title: largeText(title: 'Create Post'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _imageFile != null
                      ? Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey,
                      ),
                      child: Image.file(
                        _imageFile!,
                        height: 150,
                        width: 240,
                        fit: BoxFit.cover, // Ensure the image covers the container
                      ),
                    ),
                  )
                      : InkWell(
                    onTap: () {
                      _pickImage().then((_) {
                        // Update state after picking image
                        setState(() {});
                      });
                    },
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey,
                        ),
                        width: 240,
                        height: 150,
                        child: Icon(
                          Icons.add,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextField(
                      controller: _postController,
                      style: TextStyle(color: Colors.white), // Set text color to white
                      decoration: InputDecoration(
                        hintText: 'Enter your post content',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)), // Adjust hint color and opacity
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),


                  // SizedBox(height: 10),
                  // _imageFile != null
                  //     ? Image.file(_imageFile!, height: 150)
                  //     : SizedBox(),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.transparent,
                            border: Border.all(color: Colors.grey),
                          ),
                          width: MediaQuery.of(context).size.width * 0.25,
                          height: MediaQuery.of(context).size.height * 0.06,
                          child: Center(
                            child: largeText(
                              title: 'Cancel',
                              fontSize: 14.0,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _createPost(_postController.text, _imageFile);
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.blue,
                            border: Border.all(color: Colors.grey),
                          ),
                          width: MediaQuery.of(context).size.width * 0.25,
                          height: MediaQuery.of(context).size.height * 0.06,
                          child: Center(
                            child: largeText(
                              title: 'Post',
                              fontSize: 14.0,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createPost(String content, File? imageFile) async {
    final accessToken = await FacebookAuth.instance.accessToken;
    if (accessToken != null) {
      for (var page in _userPages!) {
        final pageAccessToken = await _getPageAccessToken(page['id']);
        if (pageAccessToken != null) {
          var uri = Uri.parse(
              'https://graph.facebook.com/v20.0/${page['id']}/photos');
          var request = http.MultipartRequest('POST', uri);
          request.headers['Authorization'] = 'Bearer $pageAccessToken';
          request.fields['caption'] = content;
          if (imageFile != null) {
            request.files.add(
              await http.MultipartFile.fromPath('source', imageFile.path),
            );
          }
          final response = await request.send();
          if (response.statusCode == 200) {
            print('Post created successfully.');
            // After creating the post, fetch the updated feed
            _fetchPageFeed(page['id'], pageAccessToken);
          } else {
            print('Failed to create post: ${response.statusCode}');
          }
        }
      }
    }
  }

  String _formatDateTime(String dateTimeString) {
    final dateTime = DateTime.parse(dateTimeString).toLocal();
    return DateFormat('yyyy-MM-dd hh:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryTextColor,
        title: largeText(
          title: 'Dashboard',
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchUserPages,
          ),
        ],
      ),
      body: _loadingPages || _loadingFeed
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        controller: _scrollController,
        itemCount: _allPageFeeds.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _allPageFeeds.length) {
            return Center(child: CircularProgressIndicator());
          }

          final post = _allPageFeeds[index];
          final String formattedDateTime =
          _formatDateTime(post['created_time']);

          return Card(
            color: secondaryTextColor,
            elevation: 2.0,
            margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  post['full_picture'] != null
                      ? Image.network(post['full_picture'])
                      : SizedBox(),
                  SizedBox(height: 10),
                  post['message'] != null
                      ? mediumText(
                    title: post['message'],
                    fontSize: 14.0,
                  )
                      : SizedBox(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      largeText(
                          title: formattedDateTime,
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey
                      ),
                    ],
                  ),

                  SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.thumb_up, size: 16.0, color: Colors.grey),
                      SizedBox(width: 4.0),
                      mediumText(
                        title: post['likes']?['summary']?['total_count']
                            ?.toString() ??
                            '0',
                        fontSize: 14.0,
                      ),
                      SizedBox(width: 16.0),
                      Icon(Icons.share, size: 16.0, color: Colors.grey),
                      SizedBox(width: 4.0),
                      mediumText(
                        title:
                        post['shares']?['count']?.toString() ?? '0',
                        fontSize: 14.0,
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Divider(),
                  ..._buildComments(post['comments']),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: CustomFloatingAction(
        onTap: () {
          _showPostDialog(context);
        },
      ),
    );
  }

  List<Widget> _buildComments(dynamic commentsData) {
    if (commentsData == null || commentsData['data'] == null) {
      return [mediumText(title: 'No comments', fontSize: 14.0)];
    }

    final comments = commentsData['data'];
    return comments.map<Widget>((comment) {
      final commenterName = comment['from']['name'];
      final commenterPictureUrl = 'https://graph.facebook.com/${comment['from']['id']}/picture?type=square';
      final commentMessage = comment['message'];
      final commentTime = _formatDateTime(comment['created_time']);

      return ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(commenterPictureUrl),
        ),
        title: mediumText(
          title: commentMessage,
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            mediumText(
              title: commenterName,
              fontSize: 11.0,
              color: Colors.grey
            ),
            SizedBox(height: 4.0),
            mediumText(
              title: commentTime,
              fontSize: 11.0,
              color: Colors.grey,
            ),
          ],
        ),
      );
    }).toList();
  }
}
