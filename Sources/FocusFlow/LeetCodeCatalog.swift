import Foundation

// Metadata only; no problem statements or solutions. See THIRD_PARTY_NOTICES.md.
enum LCCatalog {
    static let revision = "d5ebb3ea8bd4b52d605bc7aa179e22af684d31bb"
    static let source = "https://github.com/neetcode-gh/leetcode/blob/" + revision + "/.problemSiteData.json"
    static let problems: [LCProblem] = {
        let data = Data(json.utf8)
        return (try? JSONDecoder().decode([LCProblem].self, from: data)) ?? []
    }()
    static let lists: [LCCommonList] = [
        LCCommonList(id: "neetcode150", name: "NeetCode 150", url: "https://neetcode.io/practice", problemIDs: ["contains-duplicate", "valid-anagram", "two-sum", "group-anagrams", "top-k-frequent-elements", "product-of-array-except-self", "valid-sudoku", "encode-and-decode-strings", "longest-consecutive-sequence", "valid-palindrome", "two-sum-ii-input-array-is-sorted", "3sum", "container-with-most-water", "trapping-rain-water", "best-time-to-buy-and-sell-stock", "longest-substring-without-repeating-characters", "longest-repeating-character-replacement", "permutation-in-string", "minimum-window-substring", "sliding-window-maximum", "valid-parentheses", "min-stack", "evaluate-reverse-polish-notation", "generate-parentheses", "daily-temperatures", "car-fleet", "largest-rectangle-in-histogram", "binary-search", "search-a-2d-matrix", "koko-eating-bananas", "find-minimum-in-rotated-sorted-array", "search-in-rotated-sorted-array", "time-based-key-value-store", "median-of-two-sorted-arrays", "reverse-linked-list", "merge-two-sorted-lists", "reorder-list", "remove-nth-node-from-end-of-list", "copy-list-with-random-pointer", "add-two-numbers", "linked-list-cycle", "find-the-duplicate-number", "lru-cache", "merge-k-sorted-lists", "reverse-nodes-in-k-group", "invert-binary-tree", "maximum-depth-of-binary-tree", "diameter-of-binary-tree", "balanced-binary-tree", "same-tree", "subtree-of-another-tree", "lowest-common-ancestor-of-a-binary-search-tree", "binary-tree-level-order-traversal", "binary-tree-right-side-view", "count-good-nodes-in-binary-tree", "validate-binary-search-tree", "kth-smallest-element-in-a-bst", "construct-binary-tree-from-preorder-and-inorder-traversal", "binary-tree-maximum-path-sum", "serialize-and-deserialize-binary-tree", "implement-trie-prefix-tree", "design-add-and-search-words-data-structure", "word-search-ii", "kth-largest-element-in-a-stream", "last-stone-weight", "k-closest-points-to-origin", "kth-largest-element-in-an-array", "task-scheduler", "design-twitter", "find-median-from-data-stream", "subsets", "combination-sum", "permutations", "subsets-ii", "combination-sum-ii", "word-search", "palindrome-partitioning", "letter-combinations-of-a-phone-number", "n-queens", "number-of-islands", "clone-graph", "max-area-of-island", "pacific-atlantic-water-flow", "surrounded-regions", "rotting-oranges", "walls-and-gates", "course-schedule", "course-schedule-ii", "redundant-connection", "number-of-connected-components-in-an-undirected-graph", "graph-valid-tree", "word-ladder", "reconstruct-itinerary", "min-cost-to-connect-all-points", "network-delay-time", "swim-in-rising-water", "alien-dictionary", "cheapest-flights-within-k-stops", "climbing-stairs", "min-cost-climbing-stairs", "house-robber", "house-robber-ii", "longest-palindromic-substring", "palindromic-substrings", "decode-ways", "coin-change", "maximum-product-subarray", "word-break", "longest-increasing-subsequence", "partition-equal-subset-sum", "unique-paths", "longest-common-subsequence", "best-time-to-buy-and-sell-stock-with-cooldown", "coin-change-ii", "target-sum", "interleaving-string", "longest-increasing-path-in-a-matrix", "distinct-subsequences", "edit-distance", "burst-balloons", "regular-expression-matching", "maximum-subarray", "jump-game", "jump-game-ii", "gas-station", "hand-of-straights", "merge-triplets-to-form-target-triplet", "partition-labels", "valid-parenthesis-string", "insert-interval", "merge-intervals", "non-overlapping-intervals", "meeting-rooms", "meeting-rooms-ii", "minimum-interval-to-include-each-query", "rotate-image", "spiral-matrix", "set-matrix-zeroes", "happy-number", "plus-one", "powx-n", "multiply-strings", "detect-squares", "single-number", "number-of-1-bits", "counting-bits", "reverse-bits", "missing-number", "sum-of-two-integers", "reverse-integer"]),
        LCCommonList(id: "blind75", name: "Blind 75", url: "https://neetcode.io/practice?tab=blind75", problemIDs: ["contains-duplicate", "valid-anagram", "two-sum", "group-anagrams", "top-k-frequent-elements", "product-of-array-except-self", "encode-and-decode-strings", "longest-consecutive-sequence", "valid-palindrome", "3sum", "container-with-most-water", "best-time-to-buy-and-sell-stock", "longest-substring-without-repeating-characters", "longest-repeating-character-replacement", "minimum-window-substring", "valid-parentheses", "find-minimum-in-rotated-sorted-array", "search-in-rotated-sorted-array", "reverse-linked-list", "merge-two-sorted-lists", "reorder-list", "remove-nth-node-from-end-of-list", "linked-list-cycle", "merge-k-sorted-lists", "invert-binary-tree", "maximum-depth-of-binary-tree", "same-tree", "subtree-of-another-tree", "lowest-common-ancestor-of-a-binary-search-tree", "binary-tree-level-order-traversal", "validate-binary-search-tree", "kth-smallest-element-in-a-bst", "construct-binary-tree-from-preorder-and-inorder-traversal", "binary-tree-maximum-path-sum", "serialize-and-deserialize-binary-tree", "implement-trie-prefix-tree", "design-add-and-search-words-data-structure", "word-search-ii", "find-median-from-data-stream", "combination-sum", "word-search", "number-of-islands", "clone-graph", "pacific-atlantic-water-flow", "course-schedule", "number-of-connected-components-in-an-undirected-graph", "graph-valid-tree", "alien-dictionary", "climbing-stairs", "house-robber", "house-robber-ii", "longest-palindromic-substring", "palindromic-substrings", "decode-ways", "coin-change", "maximum-product-subarray", "word-break", "longest-increasing-subsequence", "unique-paths", "longest-common-subsequence", "maximum-subarray", "jump-game", "insert-interval", "merge-intervals", "non-overlapping-intervals", "meeting-rooms", "meeting-rooms-ii", "rotate-image", "spiral-matrix", "set-matrix-zeroes", "number-of-1-bits", "counting-bits", "reverse-bits", "missing-number", "sum-of-two-integers"])
    ]
    private static let json = #"""
[
  {
    "id": "contains-duplicate",
    "number": "217",
    "title": "Contains Duplicate",
    "difficulty": "Easy",
    "topics": [
      "Arrays & Hashing"
    ]
  },
  {
    "id": "valid-anagram",
    "number": "242",
    "title": "Valid Anagram",
    "difficulty": "Easy",
    "topics": [
      "Arrays & Hashing"
    ]
  },
  {
    "id": "two-sum",
    "number": "1",
    "title": "Two Sum",
    "difficulty": "Easy",
    "topics": [
      "Arrays & Hashing"
    ]
  },
  {
    "id": "group-anagrams",
    "number": "49",
    "title": "Group Anagrams",
    "difficulty": "Medium",
    "topics": [
      "Arrays & Hashing"
    ]
  },
  {
    "id": "top-k-frequent-elements",
    "number": "347",
    "title": "Top K Frequent Elements",
    "difficulty": "Medium",
    "topics": [
      "Arrays & Hashing"
    ]
  },
  {
    "id": "product-of-array-except-self",
    "number": "238",
    "title": "Product of Array Except Self",
    "difficulty": "Medium",
    "topics": [
      "Arrays & Hashing"
    ]
  },
  {
    "id": "valid-sudoku",
    "number": "36",
    "title": "Valid Sudoku",
    "difficulty": "Medium",
    "topics": [
      "Arrays & Hashing"
    ]
  },
  {
    "id": "encode-and-decode-strings",
    "number": "271",
    "title": "Encode and Decode Strings",
    "difficulty": "Medium",
    "topics": [
      "Arrays & Hashing"
    ]
  },
  {
    "id": "longest-consecutive-sequence",
    "number": "128",
    "title": "Longest Consecutive Sequence",
    "difficulty": "Medium",
    "topics": [
      "Arrays & Hashing"
    ]
  },
  {
    "id": "valid-palindrome",
    "number": "125",
    "title": "Valid Palindrome",
    "difficulty": "Easy",
    "topics": [
      "Two Pointers"
    ]
  },
  {
    "id": "two-sum-ii-input-array-is-sorted",
    "number": "167",
    "title": "Two Sum II Input Array Is Sorted",
    "difficulty": "Medium",
    "topics": [
      "Two Pointers"
    ]
  },
  {
    "id": "3sum",
    "number": "15",
    "title": "3Sum",
    "difficulty": "Medium",
    "topics": [
      "Two Pointers"
    ]
  },
  {
    "id": "container-with-most-water",
    "number": "11",
    "title": "Container With Most Water",
    "difficulty": "Medium",
    "topics": [
      "Two Pointers"
    ]
  },
  {
    "id": "trapping-rain-water",
    "number": "42",
    "title": "Trapping Rain Water",
    "difficulty": "Hard",
    "topics": [
      "Two Pointers"
    ]
  },
  {
    "id": "best-time-to-buy-and-sell-stock",
    "number": "121",
    "title": "Best Time to Buy And Sell Stock",
    "difficulty": "Easy",
    "topics": [
      "Sliding Window"
    ]
  },
  {
    "id": "longest-substring-without-repeating-characters",
    "number": "3",
    "title": "Longest Substring Without Repeating Characters",
    "difficulty": "Medium",
    "topics": [
      "Sliding Window"
    ]
  },
  {
    "id": "longest-repeating-character-replacement",
    "number": "424",
    "title": "Longest Repeating Character Replacement",
    "difficulty": "Medium",
    "topics": [
      "Sliding Window"
    ]
  },
  {
    "id": "permutation-in-string",
    "number": "567",
    "title": "Permutation In String",
    "difficulty": "Medium",
    "topics": [
      "Sliding Window"
    ]
  },
  {
    "id": "minimum-window-substring",
    "number": "76",
    "title": "Minimum Window Substring",
    "difficulty": "Hard",
    "topics": [
      "Sliding Window"
    ]
  },
  {
    "id": "sliding-window-maximum",
    "number": "239",
    "title": "Sliding Window Maximum",
    "difficulty": "Hard",
    "topics": [
      "Sliding Window"
    ]
  },
  {
    "id": "valid-parentheses",
    "number": "20",
    "title": "Valid Parentheses",
    "difficulty": "Easy",
    "topics": [
      "Stack"
    ]
  },
  {
    "id": "min-stack",
    "number": "155",
    "title": "Min Stack",
    "difficulty": "Medium",
    "topics": [
      "Stack"
    ]
  },
  {
    "id": "evaluate-reverse-polish-notation",
    "number": "150",
    "title": "Evaluate Reverse Polish Notation",
    "difficulty": "Medium",
    "topics": [
      "Stack"
    ]
  },
  {
    "id": "generate-parentheses",
    "number": "22",
    "title": "Generate Parentheses",
    "difficulty": "Medium",
    "topics": [
      "Stack"
    ]
  },
  {
    "id": "daily-temperatures",
    "number": "739",
    "title": "Daily Temperatures",
    "difficulty": "Medium",
    "topics": [
      "Stack"
    ]
  },
  {
    "id": "car-fleet",
    "number": "853",
    "title": "Car Fleet",
    "difficulty": "Medium",
    "topics": [
      "Stack"
    ]
  },
  {
    "id": "largest-rectangle-in-histogram",
    "number": "84",
    "title": "Largest Rectangle In Histogram",
    "difficulty": "Hard",
    "topics": [
      "Stack"
    ]
  },
  {
    "id": "binary-search",
    "number": "704",
    "title": "Binary Search",
    "difficulty": "Easy",
    "topics": [
      "Binary Search"
    ]
  },
  {
    "id": "search-a-2d-matrix",
    "number": "74",
    "title": "Search a 2D Matrix",
    "difficulty": "Medium",
    "topics": [
      "Binary Search"
    ]
  },
  {
    "id": "koko-eating-bananas",
    "number": "875",
    "title": "Koko Eating Bananas",
    "difficulty": "Medium",
    "topics": [
      "Binary Search"
    ]
  },
  {
    "id": "find-minimum-in-rotated-sorted-array",
    "number": "153",
    "title": "Find Minimum In Rotated Sorted Array",
    "difficulty": "Medium",
    "topics": [
      "Binary Search"
    ]
  },
  {
    "id": "search-in-rotated-sorted-array",
    "number": "33",
    "title": "Search In Rotated Sorted Array",
    "difficulty": "Medium",
    "topics": [
      "Binary Search"
    ]
  },
  {
    "id": "time-based-key-value-store",
    "number": "981",
    "title": "Time Based Key Value Store",
    "difficulty": "Medium",
    "topics": [
      "Binary Search"
    ]
  },
  {
    "id": "median-of-two-sorted-arrays",
    "number": "4",
    "title": "Median of Two Sorted Arrays",
    "difficulty": "Hard",
    "topics": [
      "Binary Search"
    ]
  },
  {
    "id": "reverse-linked-list",
    "number": "206",
    "title": "Reverse Linked List",
    "difficulty": "Easy",
    "topics": [
      "Linked List"
    ]
  },
  {
    "id": "merge-two-sorted-lists",
    "number": "21",
    "title": "Merge Two Sorted Lists",
    "difficulty": "Easy",
    "topics": [
      "Linked List"
    ]
  },
  {
    "id": "reorder-list",
    "number": "143",
    "title": "Reorder List",
    "difficulty": "Medium",
    "topics": [
      "Linked List"
    ]
  },
  {
    "id": "remove-nth-node-from-end-of-list",
    "number": "19",
    "title": "Remove Nth Node From End of List",
    "difficulty": "Medium",
    "topics": [
      "Linked List"
    ]
  },
  {
    "id": "copy-list-with-random-pointer",
    "number": "138",
    "title": "Copy List With Random Pointer",
    "difficulty": "Medium",
    "topics": [
      "Linked List"
    ]
  },
  {
    "id": "add-two-numbers",
    "number": "2",
    "title": "Add Two Numbers",
    "difficulty": "Medium",
    "topics": [
      "Linked List"
    ]
  },
  {
    "id": "linked-list-cycle",
    "number": "141",
    "title": "Linked List Cycle",
    "difficulty": "Easy",
    "topics": [
      "Linked List"
    ]
  },
  {
    "id": "find-the-duplicate-number",
    "number": "287",
    "title": "Find The Duplicate Number",
    "difficulty": "Medium",
    "topics": [
      "Linked List"
    ]
  },
  {
    "id": "lru-cache",
    "number": "146",
    "title": "LRU Cache",
    "difficulty": "Medium",
    "topics": [
      "Linked List"
    ]
  },
  {
    "id": "merge-k-sorted-lists",
    "number": "23",
    "title": "Merge K Sorted Lists",
    "difficulty": "Hard",
    "topics": [
      "Linked List"
    ]
  },
  {
    "id": "reverse-nodes-in-k-group",
    "number": "25",
    "title": "Reverse Nodes In K Group",
    "difficulty": "Hard",
    "topics": [
      "Linked List"
    ]
  },
  {
    "id": "invert-binary-tree",
    "number": "226",
    "title": "Invert Binary Tree",
    "difficulty": "Easy",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "maximum-depth-of-binary-tree",
    "number": "104",
    "title": "Maximum Depth of Binary Tree",
    "difficulty": "Easy",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "diameter-of-binary-tree",
    "number": "543",
    "title": "Diameter of Binary Tree",
    "difficulty": "Easy",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "balanced-binary-tree",
    "number": "110",
    "title": "Balanced Binary Tree",
    "difficulty": "Easy",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "same-tree",
    "number": "100",
    "title": "Same Tree",
    "difficulty": "Easy",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "subtree-of-another-tree",
    "number": "572",
    "title": "Subtree of Another Tree",
    "difficulty": "Easy",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "lowest-common-ancestor-of-a-binary-search-tree",
    "number": "235",
    "title": "Lowest Common Ancestor of a Binary Search Tree",
    "difficulty": "Medium",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "binary-tree-level-order-traversal",
    "number": "102",
    "title": "Binary Tree Level Order Traversal",
    "difficulty": "Medium",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "binary-tree-right-side-view",
    "number": "199",
    "title": "Binary Tree Right Side View",
    "difficulty": "Medium",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "count-good-nodes-in-binary-tree",
    "number": "1448",
    "title": "Count Good Nodes In Binary Tree",
    "difficulty": "Medium",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "validate-binary-search-tree",
    "number": "98",
    "title": "Validate Binary Search Tree",
    "difficulty": "Medium",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "kth-smallest-element-in-a-bst",
    "number": "230",
    "title": "Kth Smallest Element In a Bst",
    "difficulty": "Medium",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "construct-binary-tree-from-preorder-and-inorder-traversal",
    "number": "105",
    "title": "Construct Binary Tree From Preorder And Inorder Traversal",
    "difficulty": "Medium",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "binary-tree-maximum-path-sum",
    "number": "124",
    "title": "Binary Tree Maximum Path Sum",
    "difficulty": "Hard",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "serialize-and-deserialize-binary-tree",
    "number": "297",
    "title": "Serialize And Deserialize Binary Tree",
    "difficulty": "Hard",
    "topics": [
      "Trees"
    ]
  },
  {
    "id": "implement-trie-prefix-tree",
    "number": "208",
    "title": "Implement Trie Prefix Tree",
    "difficulty": "Medium",
    "topics": [
      "Tries"
    ]
  },
  {
    "id": "design-add-and-search-words-data-structure",
    "number": "211",
    "title": "Design Add And Search Words Data Structure",
    "difficulty": "Medium",
    "topics": [
      "Tries"
    ]
  },
  {
    "id": "word-search-ii",
    "number": "212",
    "title": "Word Search II",
    "difficulty": "Hard",
    "topics": [
      "Tries"
    ]
  },
  {
    "id": "kth-largest-element-in-a-stream",
    "number": "703",
    "title": "Kth Largest Element In a Stream",
    "difficulty": "Easy",
    "topics": [
      "Heap / Priority Queue"
    ]
  },
  {
    "id": "last-stone-weight",
    "number": "1046",
    "title": "Last Stone Weight",
    "difficulty": "Easy",
    "topics": [
      "Heap / Priority Queue"
    ]
  },
  {
    "id": "k-closest-points-to-origin",
    "number": "973",
    "title": "K Closest Points to Origin",
    "difficulty": "Medium",
    "topics": [
      "Heap / Priority Queue"
    ]
  },
  {
    "id": "kth-largest-element-in-an-array",
    "number": "215",
    "title": "Kth Largest Element In An Array",
    "difficulty": "Medium",
    "topics": [
      "Heap / Priority Queue"
    ]
  },
  {
    "id": "task-scheduler",
    "number": "621",
    "title": "Task Scheduler",
    "difficulty": "Medium",
    "topics": [
      "Heap / Priority Queue"
    ]
  },
  {
    "id": "design-twitter",
    "number": "355",
    "title": "Design Twitter",
    "difficulty": "Medium",
    "topics": [
      "Heap / Priority Queue"
    ]
  },
  {
    "id": "find-median-from-data-stream",
    "number": "295",
    "title": "Find Median From Data Stream",
    "difficulty": "Hard",
    "topics": [
      "Heap / Priority Queue"
    ]
  },
  {
    "id": "subsets",
    "number": "78",
    "title": "Subsets",
    "difficulty": "Medium",
    "topics": [
      "Backtracking"
    ]
  },
  {
    "id": "combination-sum",
    "number": "39",
    "title": "Combination Sum",
    "difficulty": "Medium",
    "topics": [
      "Backtracking"
    ]
  },
  {
    "id": "permutations",
    "number": "46",
    "title": "Permutations",
    "difficulty": "Medium",
    "topics": [
      "Backtracking"
    ]
  },
  {
    "id": "subsets-ii",
    "number": "90",
    "title": "Subsets II",
    "difficulty": "Medium",
    "topics": [
      "Backtracking"
    ]
  },
  {
    "id": "combination-sum-ii",
    "number": "40",
    "title": "Combination Sum II",
    "difficulty": "Medium",
    "topics": [
      "Backtracking"
    ]
  },
  {
    "id": "word-search",
    "number": "79",
    "title": "Word Search",
    "difficulty": "Medium",
    "topics": [
      "Backtracking"
    ]
  },
  {
    "id": "palindrome-partitioning",
    "number": "131",
    "title": "Palindrome Partitioning",
    "difficulty": "Medium",
    "topics": [
      "Backtracking"
    ]
  },
  {
    "id": "letter-combinations-of-a-phone-number",
    "number": "17",
    "title": "Letter Combinations of a Phone Number",
    "difficulty": "Medium",
    "topics": [
      "Backtracking"
    ]
  },
  {
    "id": "n-queens",
    "number": "51",
    "title": "N Queens",
    "difficulty": "Hard",
    "topics": [
      "Backtracking"
    ]
  },
  {
    "id": "number-of-islands",
    "number": "200",
    "title": "Number of Islands",
    "difficulty": "Medium",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "clone-graph",
    "number": "133",
    "title": "Clone Graph",
    "difficulty": "Medium",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "max-area-of-island",
    "number": "695",
    "title": "Max Area of Island",
    "difficulty": "Medium",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "pacific-atlantic-water-flow",
    "number": "417",
    "title": "Pacific Atlantic Water Flow",
    "difficulty": "Medium",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "surrounded-regions",
    "number": "130",
    "title": "Surrounded Regions",
    "difficulty": "Medium",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "rotting-oranges",
    "number": "994",
    "title": "Rotting Oranges",
    "difficulty": "Medium",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "walls-and-gates",
    "number": "286",
    "title": "Walls And Gates",
    "difficulty": "Medium",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "course-schedule",
    "number": "207",
    "title": "Course Schedule",
    "difficulty": "Medium",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "course-schedule-ii",
    "number": "210",
    "title": "Course Schedule II",
    "difficulty": "Medium",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "redundant-connection",
    "number": "684",
    "title": "Redundant Connection",
    "difficulty": "Medium",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "number-of-connected-components-in-an-undirected-graph",
    "number": "323",
    "title": "Number of Connected Components In An Undirected Graph",
    "difficulty": "Medium",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "graph-valid-tree",
    "number": "261",
    "title": "Graph Valid Tree",
    "difficulty": "Medium",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "word-ladder",
    "number": "127",
    "title": "Word Ladder",
    "difficulty": "Hard",
    "topics": [
      "Graphs"
    ]
  },
  {
    "id": "reconstruct-itinerary",
    "number": "332",
    "title": "Reconstruct Itinerary",
    "difficulty": "Hard",
    "topics": [
      "Advanced Graphs"
    ]
  },
  {
    "id": "min-cost-to-connect-all-points",
    "number": "1584",
    "title": "Min Cost to Connect All Points",
    "difficulty": "Medium",
    "topics": [
      "Advanced Graphs"
    ]
  },
  {
    "id": "network-delay-time",
    "number": "743",
    "title": "Network Delay Time",
    "difficulty": "Medium",
    "topics": [
      "Advanced Graphs"
    ]
  },
  {
    "id": "swim-in-rising-water",
    "number": "778",
    "title": "Swim In Rising Water",
    "difficulty": "Hard",
    "topics": [
      "Advanced Graphs"
    ]
  },
  {
    "id": "alien-dictionary",
    "number": "269",
    "title": "Alien Dictionary",
    "difficulty": "Hard",
    "topics": [
      "Advanced Graphs"
    ]
  },
  {
    "id": "cheapest-flights-within-k-stops",
    "number": "787",
    "title": "Cheapest Flights Within K Stops",
    "difficulty": "Medium",
    "topics": [
      "Advanced Graphs"
    ]
  },
  {
    "id": "climbing-stairs",
    "number": "70",
    "title": "Climbing Stairs",
    "difficulty": "Easy",
    "topics": [
      "1-D Dynamic Programming"
    ]
  },
  {
    "id": "min-cost-climbing-stairs",
    "number": "746",
    "title": "Min Cost Climbing Stairs",
    "difficulty": "Easy",
    "topics": [
      "1-D Dynamic Programming"
    ]
  },
  {
    "id": "house-robber",
    "number": "198",
    "title": "House Robber",
    "difficulty": "Medium",
    "topics": [
      "1-D Dynamic Programming"
    ]
  },
  {
    "id": "house-robber-ii",
    "number": "213",
    "title": "House Robber II",
    "difficulty": "Medium",
    "topics": [
      "1-D Dynamic Programming"
    ]
  },
  {
    "id": "longest-palindromic-substring",
    "number": "5",
    "title": "Longest Palindromic Substring",
    "difficulty": "Medium",
    "topics": [
      "1-D Dynamic Programming"
    ]
  },
  {
    "id": "palindromic-substrings",
    "number": "647",
    "title": "Palindromic Substrings",
    "difficulty": "Medium",
    "topics": [
      "1-D Dynamic Programming"
    ]
  },
  {
    "id": "decode-ways",
    "number": "91",
    "title": "Decode Ways",
    "difficulty": "Medium",
    "topics": [
      "1-D Dynamic Programming"
    ]
  },
  {
    "id": "coin-change",
    "number": "322",
    "title": "Coin Change",
    "difficulty": "Medium",
    "topics": [
      "1-D Dynamic Programming"
    ]
  },
  {
    "id": "maximum-product-subarray",
    "number": "152",
    "title": "Maximum Product Subarray",
    "difficulty": "Medium",
    "topics": [
      "1-D Dynamic Programming"
    ]
  },
  {
    "id": "word-break",
    "number": "139",
    "title": "Word Break",
    "difficulty": "Medium",
    "topics": [
      "1-D Dynamic Programming"
    ]
  },
  {
    "id": "longest-increasing-subsequence",
    "number": "300",
    "title": "Longest Increasing Subsequence",
    "difficulty": "Medium",
    "topics": [
      "1-D Dynamic Programming"
    ]
  },
  {
    "id": "partition-equal-subset-sum",
    "number": "416",
    "title": "Partition Equal Subset Sum",
    "difficulty": "Medium",
    "topics": [
      "1-D Dynamic Programming"
    ]
  },
  {
    "id": "unique-paths",
    "number": "62",
    "title": "Unique Paths",
    "difficulty": "Medium",
    "topics": [
      "2-D Dynamic Programming"
    ]
  },
  {
    "id": "longest-common-subsequence",
    "number": "1143",
    "title": "Longest Common Subsequence",
    "difficulty": "Medium",
    "topics": [
      "2-D Dynamic Programming"
    ]
  },
  {
    "id": "best-time-to-buy-and-sell-stock-with-cooldown",
    "number": "309",
    "title": "Best Time to Buy And Sell Stock With Cooldown",
    "difficulty": "Medium",
    "topics": [
      "2-D Dynamic Programming"
    ]
  },
  {
    "id": "coin-change-ii",
    "number": "518",
    "title": "Coin Change II",
    "difficulty": "Medium",
    "topics": [
      "2-D Dynamic Programming"
    ]
  },
  {
    "id": "target-sum",
    "number": "494",
    "title": "Target Sum",
    "difficulty": "Medium",
    "topics": [
      "2-D Dynamic Programming"
    ]
  },
  {
    "id": "interleaving-string",
    "number": "97",
    "title": "Interleaving String",
    "difficulty": "Medium",
    "topics": [
      "2-D Dynamic Programming"
    ]
  },
  {
    "id": "longest-increasing-path-in-a-matrix",
    "number": "329",
    "title": "Longest Increasing Path In a Matrix",
    "difficulty": "Hard",
    "topics": [
      "2-D Dynamic Programming"
    ]
  },
  {
    "id": "distinct-subsequences",
    "number": "115",
    "title": "Distinct Subsequences",
    "difficulty": "Hard",
    "topics": [
      "2-D Dynamic Programming"
    ]
  },
  {
    "id": "edit-distance",
    "number": "72",
    "title": "Edit Distance",
    "difficulty": "Medium",
    "topics": [
      "2-D Dynamic Programming"
    ]
  },
  {
    "id": "burst-balloons",
    "number": "312",
    "title": "Burst Balloons",
    "difficulty": "Hard",
    "topics": [
      "2-D Dynamic Programming"
    ]
  },
  {
    "id": "regular-expression-matching",
    "number": "10",
    "title": "Regular Expression Matching",
    "difficulty": "Hard",
    "topics": [
      "2-D Dynamic Programming"
    ]
  },
  {
    "id": "maximum-subarray",
    "number": "53",
    "title": "Maximum Subarray",
    "difficulty": "Medium",
    "topics": [
      "Greedy"
    ]
  },
  {
    "id": "jump-game",
    "number": "55",
    "title": "Jump Game",
    "difficulty": "Medium",
    "topics": [
      "Greedy"
    ]
  },
  {
    "id": "jump-game-ii",
    "number": "45",
    "title": "Jump Game II",
    "difficulty": "Medium",
    "topics": [
      "Greedy"
    ]
  },
  {
    "id": "gas-station",
    "number": "134",
    "title": "Gas Station",
    "difficulty": "Medium",
    "topics": [
      "Greedy"
    ]
  },
  {
    "id": "hand-of-straights",
    "number": "846",
    "title": "Hand of Straights",
    "difficulty": "Medium",
    "topics": [
      "Greedy"
    ]
  },
  {
    "id": "merge-triplets-to-form-target-triplet",
    "number": "1899",
    "title": "Merge Triplets to Form Target Triplet",
    "difficulty": "Medium",
    "topics": [
      "Greedy"
    ]
  },
  {
    "id": "partition-labels",
    "number": "763",
    "title": "Partition Labels",
    "difficulty": "Medium",
    "topics": [
      "Greedy"
    ]
  },
  {
    "id": "valid-parenthesis-string",
    "number": "678",
    "title": "Valid Parenthesis String",
    "difficulty": "Medium",
    "topics": [
      "Greedy"
    ]
  },
  {
    "id": "insert-interval",
    "number": "57",
    "title": "Insert Interval",
    "difficulty": "Medium",
    "topics": [
      "Intervals"
    ]
  },
  {
    "id": "merge-intervals",
    "number": "56",
    "title": "Merge Intervals",
    "difficulty": "Medium",
    "topics": [
      "Intervals"
    ]
  },
  {
    "id": "non-overlapping-intervals",
    "number": "435",
    "title": "Non Overlapping Intervals",
    "difficulty": "Medium",
    "topics": [
      "Intervals"
    ]
  },
  {
    "id": "meeting-rooms",
    "number": "252",
    "title": "Meeting Rooms",
    "difficulty": "Easy",
    "topics": [
      "Intervals"
    ]
  },
  {
    "id": "meeting-rooms-ii",
    "number": "253",
    "title": "Meeting Rooms II",
    "difficulty": "Medium",
    "topics": [
      "Intervals"
    ]
  },
  {
    "id": "minimum-interval-to-include-each-query",
    "number": "1851",
    "title": "Minimum Interval to Include Each Query",
    "difficulty": "Hard",
    "topics": [
      "Intervals"
    ]
  },
  {
    "id": "rotate-image",
    "number": "48",
    "title": "Rotate Image",
    "difficulty": "Medium",
    "topics": [
      "Math & Geometry"
    ]
  },
  {
    "id": "spiral-matrix",
    "number": "54",
    "title": "Spiral Matrix",
    "difficulty": "Medium",
    "topics": [
      "Math & Geometry"
    ]
  },
  {
    "id": "set-matrix-zeroes",
    "number": "73",
    "title": "Set Matrix Zeroes",
    "difficulty": "Medium",
    "topics": [
      "Math & Geometry"
    ]
  },
  {
    "id": "happy-number",
    "number": "202",
    "title": "Happy Number",
    "difficulty": "Easy",
    "topics": [
      "Math & Geometry"
    ]
  },
  {
    "id": "plus-one",
    "number": "66",
    "title": "Plus One",
    "difficulty": "Easy",
    "topics": [
      "Math & Geometry"
    ]
  },
  {
    "id": "powx-n",
    "number": "50",
    "title": "Pow(x, n)",
    "difficulty": "Medium",
    "topics": [
      "Math & Geometry"
    ]
  },
  {
    "id": "multiply-strings",
    "number": "43",
    "title": "Multiply Strings",
    "difficulty": "Medium",
    "topics": [
      "Math & Geometry"
    ]
  },
  {
    "id": "detect-squares",
    "number": "2013",
    "title": "Detect Squares",
    "difficulty": "Medium",
    "topics": [
      "Math & Geometry"
    ]
  },
  {
    "id": "single-number",
    "number": "136",
    "title": "Single Number",
    "difficulty": "Easy",
    "topics": [
      "Bit Manipulation"
    ]
  },
  {
    "id": "number-of-1-bits",
    "number": "191",
    "title": "Number of 1 Bits",
    "difficulty": "Easy",
    "topics": [
      "Bit Manipulation"
    ]
  },
  {
    "id": "counting-bits",
    "number": "338",
    "title": "Counting Bits",
    "difficulty": "Easy",
    "topics": [
      "Bit Manipulation"
    ]
  },
  {
    "id": "reverse-bits",
    "number": "190",
    "title": "Reverse Bits",
    "difficulty": "Easy",
    "topics": [
      "Bit Manipulation"
    ]
  },
  {
    "id": "missing-number",
    "number": "268",
    "title": "Missing Number",
    "difficulty": "Easy",
    "topics": [
      "Bit Manipulation"
    ]
  },
  {
    "id": "sum-of-two-integers",
    "number": "371",
    "title": "Sum of Two Integers",
    "difficulty": "Medium",
    "topics": [
      "Bit Manipulation"
    ]
  },
  {
    "id": "reverse-integer",
    "number": "7",
    "title": "Reverse Integer",
    "difficulty": "Medium",
    "topics": [
      "Bit Manipulation"
    ]
  }
]
"""#
}
