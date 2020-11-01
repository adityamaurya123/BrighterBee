import 'dart:io';

import 'package:brighter_bee/app_screens/create_post.dart';
import 'package:brighter_bee/app_screens/profile.dart';
import 'package:brighter_bee/widgets/post_card_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:rxdart/rxdart.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with AutomaticKeepAliveClientMixin {
  User user;
  int selectedSort;
  List memberOf;
  PostListBloc postListBloc;
  ScrollController controller = ScrollController();
  int previousSnapshotLength;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    selectedSort = 0;
    previousSnapshotLength = 0;
  }

  void scrollListener() {
    if (controller.position.extentAfter < 400) {
      debugPrint('At bottom!');
      postListBloc.fetchNextPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.displayName)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(
            child: CircularProgressIndicator(),
          );
        memberOf = snapshot.data.data()['communityList'];
        postListBloc = PostListBloc(selectedSort, memberOf);
        postListBloc.fetchFirstList();
        controller.addListener(scrollListener);
        return Scaffold(
            body: RefreshIndicator(
                onRefresh: postListBloc.fetchFirstList,
                child: SingleChildScrollView(
                    controller: controller,
                    physics: BouncingScrollPhysics(),
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: <Widget>[
                            InkWell(
                              child: CircleAvatar(
                                backgroundImage:
                                    CachedNetworkImageProvider(user.photoURL),
                                radius: 25.0,
                                backgroundColor: Colors.grey,
                              ),
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (BuildContext context) =>
                                            Profile(user.displayName)));
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: SizedBox(
                                height: 55.0,
                                child: FlatButton(
                                  child: Text(
                                    'Write something here...           ',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 18.0),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                CreatePost()));
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                          physics: BouncingScrollPhysics(),
                          padding: EdgeInsets.all(8),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ChoiceChip(
                                selectedColor: Theme.of(context).accentColor,
                                elevation: 10,
                                onSelected: (value) {
                                  setState(() {
                                    selectedSort = 0;
                                  });
                                },
                                label: Text('Latest',
                                    style: TextStyle(
                                        color: Theme.of(context).buttonColor)),
                                selected: selectedSort == 0,
                              ),
                              SizedBox(width: 5),
                              ChoiceChip(
                                selectedColor: Theme.of(context).accentColor,
                                elevation: 10,
                                onSelected: (value) {
                                  setState(() {
                                    selectedSort = 1;
                                  });
                                },
                                label: Text('Hot',
                                    style: TextStyle(
                                        color: Theme.of(context).buttonColor)),
                                selected: selectedSort == 1,
                              ),
                              SizedBox(width: 5),
                              ChoiceChip(
                                selectedColor: Theme.of(context).accentColor,
                                elevation: 10,
                                onSelected: (value) {
                                  setState(() {
                                    selectedSort = 2;
                                  });
                                },
                                label: Text('Most upvoted',
                                    style: TextStyle(
                                        color: Theme.of(context).buttonColor)),
                                selected: selectedSort == 2,
                              ),
                              SizedBox(width: 5),
                              ChoiceChip(
                                selectedColor: Theme.of(context).accentColor,
                                elevation: 10,
                                onSelected: (value) {
                                  setState(() {
                                    selectedSort = 3;
                                  });
                                },
                                label: Text('Most viewed',
                                    style: TextStyle(
                                        color: Theme.of(context).buttonColor)),
                                selected: selectedSort == 3,
                              ),
                            ],
                          )),
                      StreamBuilder<List<DocumentSnapshot>>(
                        stream: postListBloc.postStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            return Center(
                              child: CircularProgressIndicator(),
                            );
                          else {
                            int presentLength = snapshot.data.length;
                            return ListView.builder(
                                physics: NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: snapshot.data.length,
                                itemBuilder: (context, index) {
                                  DocumentSnapshot documentSnapshot =
                                      snapshot.data[index];
                                  String id = documentSnapshot.id;
                                  debugPrint('${snapshot.data.length}');
                                  return Column(children: [
                                    Padding(
                                        padding: EdgeInsets.only(bottom: 10),
                                        child: PostCardView(
                                            documentSnapshot.get('community'),
                                            id,
                                            true)),
                                    (index != snapshot.data.length - 1)
                                        ? Container()
                                        : buildProgressIndicator(presentLength)
                                  ]);
                                });
                          }
                        },
                      ),
                    ]))));
      },
    );
  }

  buildProgressIndicator(int presentLength) {
    if (presentLength != previousSnapshotLength) {
      previousSnapshotLength = presentLength;
      return CircularProgressIndicator();
    } else {
      return Container();
    }
  }

  @override
  bool get wantKeepAlive => true;
}

class PostListBloc {
  int selectedSort;
  List memberOf;

  bool showIndicator = false;
  List<DocumentSnapshot> documentList;
  BehaviorSubject<bool> showIndicatorController;
  BehaviorSubject<List<DocumentSnapshot>> postController;

  PostListBloc(this.selectedSort, this.memberOf) {
    showIndicatorController = BehaviorSubject<bool>();
    postController = BehaviorSubject<List<DocumentSnapshot>>();
  }

  Stream get getShowIndicatorStream => showIndicatorController.stream;

  Stream<List<DocumentSnapshot>> get postStream => postController.stream;

/*This method will automatically fetch first 10 elements from the document list */
  Future fetchFirstList() async {
    if (!showIndicator) {
      try {
        updateIndicator(true);
        documentList = (await getQuery().limit(5).get()).docs;
        postController.sink.add(documentList);
        updateIndicator(false);
      } on SocketException {
        updateIndicator(false);
        postController.sink.addError(SocketException("No Internet Connection"));
      } catch (e) {
        updateIndicator(false);
        print(e.toString());
        postController.sink.addError(e);
      }
    }
  }

/*This will automatically fetch the next 10 elements from the list*/
  fetchNextPosts() async {
    if (!showIndicator) {
      try {
        updateIndicator(true);
        List<DocumentSnapshot> newDocumentList = (await getQuery()
                .startAfterDocument(documentList[documentList.length - 1])
                .limit(5)
                .get())
            .docs;
        documentList.addAll(newDocumentList);
        postController.sink.add(documentList);
        updateIndicator(false);
      } on SocketException {
        postController.sink.addError(SocketException("No Internet Connection"));
      } catch (e) {
        print(e.toString());
        postController.sink.addError(e);
      }
    }
  }

  updateIndicator(bool value) async {
    showIndicator = value;
    showIndicatorController.sink.add(value);
  }

  void dispose() {
    postController.close();
    showIndicatorController.close();
  }

  /*
  * 0 -> latest
  * 1 -> hot
  * 2 -> most upvoted
  * 3 -> most viewed
   */

  Query getQuery() {
    switch (selectedSort) {
      case 0:
        return FirebaseFirestore.instance
            .collectionGroup('posts')
            .where('isVerified', isEqualTo: true)
            .where('community', whereIn: memberOf)
            .orderBy('time', descending: true);
        break;
      case 1:
        return FirebaseFirestore.instance
            .collectionGroup('posts')
            .where('isVerified', isEqualTo: true)
            .where('community', whereIn: memberOf)
            .orderBy('weight', descending: true);
        break;
      case 2:
        return FirebaseFirestore.instance
            .collectionGroup('posts')
            .where('isVerified', isEqualTo: true)
            .where('community', whereIn: memberOf)
            .orderBy('upvotes', descending: true);
        break;
      case 3:
        return FirebaseFirestore.instance
            .collectionGroup('posts')
            .where('isVerified', isEqualTo: true)
            .where('community', whereIn: memberOf)
            .orderBy('views', descending: true);
        break;
    }
    debugPrint('Unexpected sorting selected');
    return null;
  }
}
