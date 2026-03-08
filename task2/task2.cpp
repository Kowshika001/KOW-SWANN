#include <iostream>
#include <vector>
#include <list>
#include <map>
#include <set>
#include <queue>

// 2.1 Sparse Matrix Representation Node
struct SparseNode {
    int row, col, value;
};

// A region is a collection of nodes forming a connected component
using Region = std::vector<SparseNode>;

// Forward declaration
void printMatrix(const std::vector<std::vector<int>>& matrix, const std::string& title);

class SparseImage {
public:
    int rows, cols;
    std::list<SparseNode> pixel_list;

    // Constructor from dense matrix
    SparseImage(const std::vector<std::vector<int>>& dense_matrix) {
        rows = dense_matrix.size();
        if (rows > 0) cols = dense_matrix[0].size();
        else cols = 0;

        for (int r = 0; r < rows; ++r) {
            for (int c = 0; c < cols; ++c) {
                if (dense_matrix[r][c] != 0) {
                    pixel_list.push_back({r, c, dense_matrix[r][c]});
                }
            }
        }
    }

    // Helper to get a unique key for a pixel
    int getPixelKey(int r, int c) const {
        return r * cols + c;
    }

    // 2.1 Sparse Matrix Representation Output
    void printSparseRepresentation() const {
        std::cout << "Sparse Representation" << std::endl;
        for (auto it = pixel_list.begin(); it != pixel_list.end(); ++it) {
            std::cout << "(" << it->row << ", " << it->col << ")";
            if (std::next(it) != pixel_list.end()) {
                std::cout << " -> ";
            }
        }
        std::cout << "\n" << std::endl;
    }

    // 2.2 Detection of Connected Components using BFS
    std::vector<Region> detectConnectedComponents() const {
        std::vector<Region> all_regions;
        std::set<int> all_pixel_keys;
        for (const auto& node : pixel_list) {
            all_pixel_keys.insert(getPixelKey(node.row, node.col));
        }

        std::map<int, bool> visited;
        for (const auto& start_node : pixel_list) {
            int start_key = getPixelKey(start_node.row, start_node.col);
            if (visited.find(start_key) == visited.end()) {
                Region current_region;
                std::queue<SparseNode> q;
                
                q.push(start_node);
                visited[start_key] = true;

                int dr[] = {-1, 1, 0, 0};
                int dc[] = {0, 0, -1, 1};

                while(!q.empty()) {
                    SparseNode current_node = q.front();
                    q.pop();
                    current_region.push_back(current_node);

                    for (int i=0; i<4; ++i) {
                        int nr = current_node.row + dr[i];
                        int nc = current_node.col + dc[i];
                        int neighbor_key = getPixelKey(nr, nc);

                        // Check if neighbor is a foreground pixel and not visited
                        if (all_pixel_keys.count(neighbor_key) && visited.find(neighbor_key) == visited.end()) {
                            visited[neighbor_key] = true;
                            // We need to find the actual node to push to queue
                            for(const auto& potential_neighbor : pixel_list) {
                                if(potential_neighbor.row == nr && potential_neighbor.col == nc) {
                                    q.push(potential_neighbor);
                                    break;
                                }
                            }
                        }
                    }
                }
                all_regions.push_back(current_region);
            }
        }
        return all_regions;
    }

    // 2.5 Image Reconstruction
    void reconstructAndPrint(const std::vector<Region>& regions) {
        std::vector<std::vector<int>> recon_matrix(rows, std::vector<int>(cols, 0));
        int region_id = 1;
        for (const auto& region : regions) {
            for (const auto& node : region) {
                recon_matrix[node.row][node.col] = region_id;
            }
            region_id++;
        }
        printMatrix(recon_matrix, "Reconstructed Matrix");
    }
};

// 2.3 Area Calculation & 2.4 Boundary Pixel Detection
void analyzeRegions(const std::vector<Region>& regions) {
    std::cout << "Detected Regions" << std::endl;
    int region_id = 1;
    for (const auto& region : regions) {
        // Area
        std::cout << "Region " << region_id << ": Area = " << region.size() << " pixels" << std::endl;

        // Boundary Pixels
        std::set<std::pair<int, int>> region_pixel_coords;
        for(const auto& node : region) {
            region_pixel_coords.insert({node.row, node.col});
        }
        
        std::cout << "  Boundary: ";
        bool first = true;
        for (const auto& node : region) {
             int dr[] = {-1, 1, 0, 0};
             int dc[] = {0, 0, -1, 1};
             bool is_boundary = false;
             for (int i = 0; i < 4; ++i) {
                 int nr = node.row + dr[i];
                 int nc = node.col + dc[i];
                 // Check if neighbor is outside this region
                 if (region_pixel_coords.find({nr, nc}) == region_pixel_coords.end()) {
                     is_boundary = true;
                     break;
                 }
             }
             if (is_boundary) {
                if(!first) std::cout << ", ";
                std::cout << "(" << node.row << ", " << node.col << ")";
                first = false;
             }
        }
        std::cout << "\n" << std::endl;
        region_id++;
    }
}


// Helper to print a matrix
void printMatrix(const std::vector<std::vector<int>>& matrix, const std::string& title) {
    std::cout << title << std::endl;
    for (const auto& row : matrix) {
        for (int val : row) {
            std::cout << val << " ";
        }
        std::cout << std::endl;
    }
    std::cout << std::endl;
}

int main() {
    std::cout << "IC253 Assignment 1 - Task 2\n";
    std::cout << "---------------------------\n\n";

    // 2.8 Test Case 1
    std::cout << "2.8 Test Case 1\n\n";
    std::vector<std::vector<int>> image_matrix1 = {
        {1, 1, 1, 0, 0, 0, 0},
        {1, 1, 1, 0, 0, 1, 1},
        {0, 1, 0, 0, 0, 1, 1},
    };
    
    printMatrix(image_matrix1, "Input Matrix");

    SparseImage sparse_img1(image_matrix1);
    sparse_img1.printSparseRepresentation();

    auto regions1 = sparse_img1.detectConnectedComponents();
    analyzeRegions(regions1);
    
    sparse_img1.reconstructAndPrint(regions1);

    return 0;
}