#include <iostream>
#include <vector>
#include <queue>
#include <list>
#include <algorithm>
#include <cmath>
#include <set>

// Define PI for circularity calculation
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Structure to hold pixel coordinates
struct Point {
    int r, c;
};

// Structure to hold information about a detected component/object
struct DetectedObject {
    int id;
    std::vector<Point> pixels;
    int pixel_count = 0;
    int min_r, max_r, min_c, max_c; // Bounding box
};

// 1.2 Connected Component Detection (BFS-based)
std::vector<DetectedObject> detectComponents(const std::vector<std::vector<int>>& image, int threshold) {
    if (image.empty() || image[0].empty()) {
        return {};
    }

    int rows = image.size();
    int cols = image[0].size();
    std::vector<std::vector<bool>> visited(rows, std::vector<bool>(cols, false));
    std::vector<DetectedObject> components;
    int component_id = 0;

    int dr[] = {-1, 1, 0, 0}; // Directions for row
    int dc[] = {0, 0, -1, 1}; // Directions for column

    for (int r = 0; r < rows; ++r) {
        for (int c = 0; c < cols; ++c) {
            // If pixel is above threshold and not visited, start BFS for a new component
            if (image[r][c] > threshold && !visited[r][c]) {
                component_id++;
                DetectedObject current_component;
                current_component.id = component_id;
                current_component.min_r = r;
                current_component.max_r = r;
                current_component.min_c = c;
                current_component.max_c = c;
                
                std::queue<Point> q;
                q.push({r, c});
                visited[r][c] = true;

                while (!q.empty()) {
                    Point current_pixel = q.front();
                    q.pop();

                    current_component.pixels.push_back(current_pixel);
                    current_component.min_r = std::min(current_component.min_r, current_pixel.r);
                    current_component.max_r = std::max(current_component.max_r, current_pixel.r);
                    current_component.min_c = std::min(current_component.min_c, current_pixel.c);
                    current_component.max_c = std::max(current_component.max_c, current_pixel.c);

                    // Check neighbors
                    for (int i = 0; i < 4; ++i) {
                        int nr = current_pixel.r + dr[i];
                        int nc = current_pixel.c + dc[i];

                        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols &&
                            image[nr][nc] > threshold && !visited[nr][nc]) {
                            visited[nr][nc] = true;
                            q.push({nr, nc});
                        }
                    }
                }
                current_component.pixel_count = current_component.pixels.size();
                components.push_back(current_component);
            }
        }
    }
    return components;
}

// Helper to calculate perimeter for circularity
double calculatePerimeter(const DetectedObject& obj) {
    std::set<std::pair<int, int>> pixel_set;
    for(const auto& p : obj.pixels) {
        pixel_set.insert({p.r, p.c});
    }

    int perimeter = 0;
    int dr[] = {-1, 1, 0, 0}; // Directions for row
    int dc[] = {0, 0, -1, 1}; // Directions for column

    for (const auto& p : obj.pixels) {
        for (int i = 0; i < 4; ++i) {
            int nr = p.r + dr[i];
            int nc = p.c + dc[i];
            if (pixel_set.find({nr, nc}) == pixel_set.end()) {
                perimeter++;
            }
        }
    }
    return perimeter;
}

// 1.5 Filtering Valid Shapes
std::vector<DetectedObject> filterValidShapes(const std::vector<DetectedObject>& components) {
    std::vector<DetectedObject> valid_shapes;

    for (const auto& region : components) {
        bool is_rectangle = false;
        bool is_circle = false;

        // 1.3 Rectangle Detection
        int box_width = region.max_c - region.min_c + 1;
        int box_height = region.max_r - region.min_r + 1;
        long box_area = (long)box_width * box_height;
        if (box_area == region.pixel_count) {
            is_rectangle = true;
        }

        // 1.4 Circle Detection
        double aspect_ratio = static_cast<double>(box_width) / box_height;
        // Check if bounding box is reasonably square-like
        if (aspect_ratio > 0.75 && aspect_ratio < 1.33) {
            double area = region.pixel_count;
            double perimeter = calculatePerimeter(region);
            if (perimeter > 0) {
                double circularity = (4 * M_PI * area) / (perimeter * perimeter);
                if (circularity > 0.7) { // Threshold for circularity
                    is_circle = true;
                }
            }
        }
        
        if (is_rectangle || is_circle) {
            valid_shapes.push_back(region);
        }
    }
    return valid_shapes;
}

// 1.6 Output Generation
void generateOutputImage(const std::vector<std::vector<int>>& original_image, const std::vector<DetectedObject>& valid_shapes) {
    if (original_image.empty()) return;
    std::vector<std::vector<int>> output_image(original_image.size(), std::vector<int>(original_image[0].size(), 0));

    for (const auto& shape : valid_shapes) {
        for (const auto& pixel : shape.pixels) {
            output_image[pixel.r][pixel.c] = original_image[pixel.r][pixel.c];
        }
    }
    
    std::cout << "\n(b) Detected Shapes:" << std::endl;
    for (const auto& row : output_image) {
        for(int val : row) {
            std::cout << (val > 0 ? "#" : ".");
        }
        std::cout << std::endl;
    }
}

void printInputImage(const std::vector<std::vector<int>>& image) {
    std::cout << "(a) Input Image:" << std::endl;
    for (const auto& row : image) {
        for(int val : row) {
            std::cout << (val > 0 ? "#" : ".");
        }
        std::cout << std::endl;
    }
}

int main() {
    std::cout << "IC253 Assignment 1 - Task 1\n";
    std::cout << "---------------------------\n\n";

    // 1.9 Test Case 1: Simple Geometric Shapes
    std::cout << "1.9 Test Case 1: Simple Geometric Shapes\n";
    std::vector<std::vector<int>> image1 = {
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 150, 150, 150, 150, 0, 0, 0, 0, 150, 150, 0, 0, 0, 0, 0},
        {0, 0, 150, 150, 150, 150, 0, 0, 0, 150, 150, 150, 150, 0, 0, 0, 0},
        {0, 0, 150, 150, 150, 150, 0, 0, 150, 150, 150, 150, 150, 150, 0, 0, 0},
        {0, 0, 150, 150, 150, 150, 0, 0, 0, 150, 150, 150, 150, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 150, 150, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 150, 0, 0, 0, 0, 0, 0, 0}, // An invalid shape to be filtered
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    };

    printInputImage(image1);
    
    int intensity_threshold = 100;
    auto components1 = detectComponents(image1, intensity_threshold);
    auto valid_shapes1 = filterValidShapes(components1);
    
    generateOutputImage(image1, valid_shapes1);

    std::cout << "\nAlgorithm detected " << valid_shapes1.size() << " valid shape(s)." << std::endl;
    
    return 0;
}