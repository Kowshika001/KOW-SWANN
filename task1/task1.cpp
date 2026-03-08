#include <iostream>
#include <vector>
#include <queue>
#include <algorithm>

// Structure to hold pixel coordinates
struct Point {
    int r, c;
};

// Structure to hold information about a detected object
struct DetectedObject {
    int min_r, max_r, min_c, max_c; // Bounding box
    int pixel_count;
    std::vector<Point> pixels; // Pixels belonging to the object
};

// Function to print the image with bounding boxes
void printImageWithBoundingBox(const std::vector<std::vector<int>>& image, const std::vector<DetectedObject>& objects) {
    std::vector<std::string> output_image(image.size(), std::string(image[0].size(), ' '));

    // First, mark the original pixels
    for (size_t r = 0; r < image.size(); ++r) {
        for (size_t c = 0; c < image[0].size(); ++c) {
            if (image[r][c] > 0) {
                output_image[r][c] = '#';
            }
        }
    }

    // Draw bounding boxes
    for (const auto& obj : objects) {
        // Draw top and bottom borders
        for (int c = obj.min_c; c <= obj.max_c; ++c) {
            if (output_image[obj.min_r][c] == ' ') output_image[obj.min_r][c] = '-';
            if (output_image[obj.max_r][c] == ' ') output_image[obj.max_r][c] = '-';
        }
        // Draw left and right borders
        for (int r = obj.min_r; r <= obj.max_r; ++r) {
            if (output_image[r][obj.min_c] == ' ') output_image[r][obj.min_c] = '|';
            if (output_image[r][obj.max_c] == ' ') output_image[r][obj.max_c] = '|';
        }
        // Draw corners
        output_image[obj.min_r][obj.min_c] = '+';
        output_image[obj.min_r][obj.max_c] = '+';
        output_image[obj.max_r][obj.min_c] = '+';
        output_image[obj.max_r][obj.max_c] = '+';
    }

    // Print the final result
    for (const auto& row : output_image) {
        std::cout << row << std::endl;
    }
}

// BFS-based object detection function
std::vector<DetectedObject> detectObjects(const std::vector<std::vector<int>>& image, int threshold) {
    if (image.empty() || image[0].empty()) {
        return {};
    }

    int rows = image.size();
    int cols = image[0].size();
    std::vector<std::vector<bool>> visited(rows, std::vector<bool>(cols, false));
    std::vector<DetectedObject> detected_objects;

    int dr[] = {-1, 1, 0, 0}; // Directions for row
    int dc[] = {0, 0, -1, 1}; // Directions for column

    for (int r = 0; r < rows; ++r) {
        for (int c = 0; c < cols; ++c) {
            // If pixel is above threshold and not visited, start BFS for a new object
            if (image[r][c] > threshold && !visited[r][c]) {
                DetectedObject current_object;
                current_object.min_r = r;
                current_object.max_r = r;
                current_object.min_c = c;
                current_object.max_c = c;
                current_object.pixel_count = 0;
                
                std::queue<Point> q;
                q.push({r, c});
                visited[r][c] = true;

                while (!q.empty()) {
                    Point current_pixel = q.front();
                    q.pop();

                    current_object.pixels.push_back(current_pixel);
                    current_object.pixel_count++;
                    current_object.min_r = std::min(current_object.min_r, current_pixel.r);
                    current_object.max_r = std::max(current_object.max_r, current_pixel.r);
                    current_object.min_c = std::min(current_object.min_c, current_pixel.c);
                    current_object.max_c = std::max(current_object.max_c, current_pixel.c);

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
                detected_objects.push_back(current_object);
            }
        }
    }
    return detected_objects;
}

// Function to classify objects and print information
void classifyAndPrintObjects(const std::vector<DetectedObject>& objects) {
    std::cout << "Detected " << objects.size() << " object(s)." << std::endl;
    int i = 1;
    for (const auto& obj : objects) {
        int box_area = (obj.max_r - obj.min_r + 1) * (obj.max_c - obj.min_c + 1);
        float density = static_cast<float>(obj.pixel_count) / box_area;

        std::cout << "\n--- Object " << i << " ---" << std::endl;
        std::cout << "Bounding Box: (" << obj.min_r << "," << obj.min_c << ") to (" 
                  << obj.max_r << "," << obj.max_c << ")" << std::endl;
        std::cout << "Pixel Count: " << obj.pixel_count << std::endl;
        std::cout << "Bounding Box Area: " << box_area << std::endl;
        std::cout << "Density: " << density << std::endl;

        // Simple classification based on density
        if (density > 0.9) {
            std::cout << "Classification: Likely a solid/rectangular object." << std::endl;
        } else {
            // A simple heuristic for circles is that their density is around PI/4 (~0.785)
            if (density > 0.6 && density < 0.85) {
                 std::cout << "Classification: Potentially a circular or irregular blob." << std::endl;
            } else {
                 std::cout << "Classification: Irregularly shaped object." << std::endl;
            }
        }
        i++;
    }
}


int main() {
    std::cout << "********* Example 1: Rectangular Object *********" << std::endl;
    std::vector<std::vector<int>> image1 = {
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 150, 160, 155, 150, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 155, 165, 160, 155, 0, 0, 200, 210, 0, 0, 0},
        {0, 0, 160, 170, 165, 160, 0, 0, 210, 200, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    };

    int intensity_threshold = 100;
    auto objects1 = detectObjects(image1, intensity_threshold);
    classifyAndPrintObjects(objects1);
    std::cout << "\nOutput Image:" << std::endl;
    printImageWithBoundingBox(image1, objects1);


    std::cout << "\n\n********* Example 2: Circular/Irregular Object *********" << std::endl;
    std::vector<std::vector<int>> image2 = {
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {0, 0, 0, 180, 190, 185, 0, 0, 0, 0, 0},
        {0, 0, 180, 190, 200, 195, 180, 0, 0, 0, 0},
        {0, 190, 200, 210, 205, 200, 195, 185, 0, 0, 0},
        {0, 0, 180, 190, 200, 195, 180, 0, 0, 0, 0},
        {0, 0, 0, 180, 190, 185, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    };
    
    auto objects2 = detectObjects(image2, intensity_threshold);
    classifyAndPrintObjects(objects2);
    std::cout << "\nOutput Image:" << std::endl;
    printImageWithBoundingBox(image2, objects2);

    return 0;
}