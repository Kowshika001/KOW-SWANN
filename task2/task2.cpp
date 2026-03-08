#include <iostream>
#include <vector>
#include <list>
#include <map>
#include <set>
#include <numeric>

// Struct for a node in the sparse linked list
struct SparseNode {
    int row, col;
};

// A map to represent disjoint sets for connected components
// (Implements a simplified union-find)
using DisjointSets = std::map<int, int>;

// Function to find the representative of a set
int find_set(DisjointSets& ds, int i) {
    if (ds.find(i) == ds.end() || ds[i] == i)
        return i;
    return ds[i] = find_set(ds, ds[i]);
}

// Function to unite two sets
void unite_sets(DisjointSets& ds, int i, int j) {
    int root_i = find_set(ds, i);
    int root_j = find_set(ds, j);
    if (root_i != root_j) {
        ds[root_i] = root_j;
    }
}

// Main class to handle the sparse image representation
class SparseImage {
public:
    int rows, cols;
    std::list<SparseNode> pixels;

    SparseImage(const std::vector<std::vector<int>>& dense_matrix) {
        rows = dense_matrix.size();
        cols = dense_matrix[0].size();
        for (int r = 0; r < rows; ++r) {
            for (int c = 0; c < cols; ++c) {
                if (dense_matrix[r][c] != 0) {
                    pixels.push_back({r, c});
                }
            }
        }
    }

    // Print the sparse list representation
    void printSparse() const {
        std::cout << "Sparse Matrix Representation (row, col):" << std::endl;
        for (const auto& node : pixels) {
            std::cout << "(" << node.row << ", " << node.col << ") -> ";
        }
        std::cout << "NULL" << std::endl;
    }
    
    // Helper to get a unique key for a pixel
    int get_pixel_key(int r, int c) const {
        return r * cols + c;
    }

    // 1. Identify distinct objects and compute their areas
    void analyzeObjects() const {
        if (pixels.empty()) {
            std::cout << "No objects found." << std::endl;
            return;
        }

        DisjointSets ds;
        std::map<int, SparseNode> key_to_node;
        for(const auto& p : pixels) {
            key_to_node[get_pixel_key(p.row, p.col)] = p;
        }

        for (const auto& node : pixels) {
            int p_key = get_pixel_key(node.row, node.col);
            // Check neighbor to the top
            if (node.row > 0 && key_to_node.count(get_pixel_key(node.row - 1, node.col))) {
                unite_sets(ds, p_key, get_pixel_key(node.row-1, node.col));
            }
            // Check neighbor to the left
            if (node.col > 0 && key_to_node.count(get_pixel_key(node.row, node.col - 1))) {
                unite_sets(ds, p_key, get_pixel_key(node.row, node.col - 1));
            }
        }

        std::map<int, int> object_areas;
        for (const auto& node : pixels) {
            object_areas[find_set(ds, get_pixel_key(node.row, node.col))]++;
        }

        std::cout << "\nNumber of connected components detected: " << object_areas.size() << std::endl;
        int i = 1;
        for (const auto& pair : object_areas) {
            std::cout << "Object " << i++ << " area: " << pair.second << " pixels" << std::endl;
        }
    }

    // 2. Detect and list edge pixels
    void detectBoundary() const {
        std::set<int> pixel_keys;
        for(const auto& p : pixels) {
            pixel_keys.insert(get_pixel_key(p.row, p.col));
        }

        std::cout << "\nBoundary pixels (row, col):" << std::endl;
        bool first = true;
        for (const auto& node : pixels) {
            int dr[] = {-1, 1, 0, 0};
            int dc[] = {0, 0, -1, 1};
            bool is_boundary = false;
            for(int i=0; i<4; ++i) {
                int nr = node.row + dr[i];
                int nc = node.col + dc[i];
                 // A pixel is a boundary if it has a background neighbor (0).
                 // A background neighbor is one that is NOT in our set of foreground pixels.
                if (nr < 0 || nr >= rows || nc < 0 || nc >= cols || !pixel_keys.count(get_pixel_key(nr, nc))) {
                    is_boundary = true;
                    break;
                }
            }

            if (is_boundary) {
                 if (!first) std::cout << ", ";
                 std::cout << "(" << node.row << ", " << node.col << ")";
                 first = false;
            }
        }
        std::cout << std::endl;
    }

    // 3. Flip foreground and background pixels
    SparseImage flip() const {
        std::vector<std::vector<int>> flipped_dense(rows, std::vector<int>(cols, 1));
        for(const auto& node : pixels) {
            flipped_dense[node.row][node.col] = 0;
        }
        return SparseImage(flipped_dense);
    }
    
    // 4. Reconstruct the image into matrix form
    std::vector<std::vector<int>> toDenseMatrix() const {
        std::vector<std::vector<int>> dense(rows, std::vector<int>(cols, 0));
        for(const auto& node : pixels) {
            dense[node.row][node.col] = 1;
        }
        return dense;
    }

    // Helper to print a dense matrix
    static void printDense(const std::vector<std::vector<int>>& dense_matrix, const std::string& title) {
        std::cout << "\n" << title << ":" << std::endl;
        for (const auto& row : dense_matrix) {
            for (int val : row) {
                std::cout << val << " ";
            }
            std::cout << std::endl;
        }
    }
};

int main() {
    std::cout << "********* Task 2 Demonstration *********" << std::endl;
    
    // Example from prompt
    std::vector<std::vector<int>> image_matrix = {
        {1, 1, 0, 0, 0, 1, 0, 0},
        {0, 1, 0, 0, 0, 1, 0, 0},
        {0, 0, 0, 1, 1, 0, 0, 0},
        {0, 0, 0, 1, 1, 0, 1, 1},
        {1, 0, 0, 0, 0, 0, 1, 0}
    };
    
    SparseImage::printDense(image_matrix, "Original Image Matrix");

    // 1. Convert to sparse representation
    SparseImage sparse_img(image_matrix);
    sparse_img.printSparse();

    // 2. Analyze objects
    sparse_img.analyzeObjects();

    // 3. Detect boundary pixels
    sparse_img.detectBoundary();

    // 4. Flip pixels
    std::cout << "\n--- Flipping Image ---";
    SparseImage flipped_img = sparse_img.flip();
    flipped_img.printSparse();

    // 5. Reconstruct the flipped image
    auto reconstructed_matrix = flipped_img.toDenseMatrix();
    SparseImage::printDense(reconstructed_matrix, "Final Reconstructed (Flipped) Image Matrix");


    std::cout << "\n\n********* Second Output Example *********" << std::endl;
    std::vector<std::vector<int>> image_matrix2 = {
        {0, 0, 0, 0, 0},
        {0, 1, 1, 1, 0},
        {0, 1, 0, 1, 0},
        {0, 1, 1, 1, 0},
        {0, 0, 0, 0, 0}
    };

    SparseImage::printDense(image_matrix2, "Original Image Matrix 2");
    SparseImage sparse_img2(image_matrix2);
    sparse_img2.printSparse();
    sparse_img2.analyzeObjects();
    sparse_img2.detectBoundary();

    return 0;
}