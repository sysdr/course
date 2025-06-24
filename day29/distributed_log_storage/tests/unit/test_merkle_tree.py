import unittest
from src.anti_entropy.merkle_tree import MerkleTree

class TestMerkleTree(unittest.TestCase):
    
    def test_empty_tree(self):
        tree = MerkleTree([])
        self.assertIsNone(tree.root)
        self.assertEqual(tree.get_root_hash(), "")
    
    def test_single_item_tree(self):
        tree = MerkleTree(["data1"])
        self.assertIsNotNone(tree.root)
        self.assertTrue(len(tree.get_root_hash()) > 0)
    
    def test_tree_comparison_identical(self):
        data = ["data1", "data2", "data3"]
        tree1 = MerkleTree(data)
        tree2 = MerkleTree(data)
        
        self.assertEqual(tree1.get_root_hash(), tree2.get_root_hash())
        differences = tree1.compare_with(tree2)
        self.assertEqual(len(differences), 0)
    
    def test_tree_comparison_different(self):
        tree1 = MerkleTree(["data1", "data2"])
        tree2 = MerkleTree(["data1", "data3"])
        
        self.assertNotEqual(tree1.get_root_hash(), tree2.get_root_hash())
        differences = tree1.compare_with(tree2)
        self.assertGreater(len(differences), 0)

if __name__ == '__main__':
    unittest.main()
