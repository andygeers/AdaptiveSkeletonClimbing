//
//  Slice.swift
//  AdaptiveSkeletonClimbing
//
//  Created by Andy Geers on 24/07/2020.
//

import Foundation
import Euclid

public class Slice {
    private let z : Int
    private let zOffset : Double   /// Offset compared to previous layer
    private let offset : Int
    private let contourTracer : ContourTracer
    private let previousSlice : Slice?
    public let depthCounts : [Int]
    
    // See generatePolygons for the diagram
    static let vertexOffsets = [
        Vector( 0,  0, 0),
        Vector(-1,  1, 0),
        Vector( 0,  1, 0),
        Vector( 1,  1, 0),
        Vector(-1,  0, 0),
        Vector( 1,  0, 0),
        Vector(-1, -1, 0),
        Vector( 0, -1, 0),
        Vector( 1, -1, 0)
    ]
    
    public init?(contourTracer: ContourTracer, z: Int, previousSlice: Slice?) {
        guard z >= -1 && z <= contourTracer.G_DataDepth else { return nil }
        guard z == 0 || z == contourTracer.G_DataDepth - 1 || previousSlice != nil else { return nil }
            
        self.z = z
        let previousZ = (previousSlice?.z ?? (z == 0 ? -1 : contourTracer.G_DataDepth))
        self.zOffset = Double(z - previousZ)
        self.contourTracer = contourTracer
        self.previousSlice = previousSlice
        
        if (z == -1 || z == contourTracer.G_DataDepth) {
            self.offset = -1
        } else {
            self.offset = z * (contourTracer.G_DataWidth * contourTracer.G_DataHeight)
        }
        
        depthCounts = Slice.calculateUpdatedDepthCounts(contourTracer: contourTracer, offset: offset, previousSlice: previousSlice)
    }
    
    private static func calculateUpdatedDepthCounts(contourTracer: ContourTracer, offset: Int, previousSlice: Slice?) -> [Int] {
        
        var depths = [Int](repeating: 0, count: contourTracer.G_DataWidth * contourTracer.G_DataHeight)
        
        var k = 0
        for _ in 0 ..< contourTracer.G_DataHeight { // y
            for _ in 0 ..< contourTracer.G_DataWidth { // x
                let filled = offset >= 0 ? (Double(contourTracer.G_data1[k + offset]) > ContourTracer.G_Threshold) : false
                if let lastSlice = previousSlice {
                    let lastDepth = lastSlice.depthCounts[k]
                    if (filled) {
                        if (lastDepth > 0) {
                            depths[k] = lastDepth + 1
                        } else {
                            depths[k] = 1
                        }
                    } else {
                        if (lastDepth < 0) {
                            depths[k] = lastDepth - 1
                        } else if (lastDepth > 0) {
                            depths[k] = -1
                        }
                    }
                } else {
                    if (filled) {
                        depths[k] = 1
                    }
                }
                
                k += 1
            }
        }
        return depths
    }
    
    public func generatePolygons(_ polygons : inout [Euclid.Polygon], material: Euclid.Polygon.Material = UIColor.blue) {
        var k = 0
        for y in 0 ..< contourTracer.G_DataHeight {
            for x in 0 ..< contourTracer.G_DataWidth {
                let depth = depthCounts[k]
                
                let centre = Vector(Double(x), Double(y), Double(z))
                
                var vertexPositions : [[Vector]] = []
                
                // See if we're newly filled
                if (depth == 1) {
                    
                    /*
                        1/////2////3
                        //  ///  ///
                        // / // / //
                        4/////0////5
                        //  ///  ///
                        // / // / //
                        6/////7////8
                     */
                    // See if any of the other eight vertices are available yet
                    let depths = [
                        depth,
                        x > 0 && y < contourTracer.G_DataHeight ? depthCounts[k - 1 + contourTracer.G_DataWidth] : 0,
                        y < contourTracer.G_DataHeight ? depthCounts[k + contourTracer.G_DataWidth] : 0,
                        x < contourTracer.G_DataWidth && y < contourTracer.G_DataHeight ? depthCounts[k + 1 + contourTracer.G_DataWidth] : 0,
                        x > 0 ? depthCounts[k - 1] : 0,
                        x < contourTracer.G_DataWidth ? depthCounts[k + 1] : 0,
                        x > 0 && y > 0 ? depthCounts[k - 1 - contourTracer.G_DataWidth] : 0,
                        x < contourTracer.G_DataWidth && y > 0 ? depthCounts[k + 1 - contourTracer.G_DataWidth] : 0
                    ]
                    if (depths[3] > 0) {
                        if (depths[2] > 0) {
                            vertexPositions.append([0, 3, 2].map { centre + Slice.vertexOffsets[$0] - Vector(0.0, 0.0, (Double(depths[$0] - 1) * zOffset)) })
                        }
                        if (depths[5] > 0) {
                            vertexPositions.append([0, 5, 3].map { centre + Slice.vertexOffsets[$0] - Vector(0.0, 0.0, (Double(depths[$0] - 1) * zOffset)) })
                        }
                    }
                    if (depths[4] > depth) {
                        if (depths[2] > 0) {
                            vertexPositions.append([0, 4, 2].map { centre + Slice.vertexOffsets[$0] - Vector(0.0, 0.0, (Double(depths[$0] - 1) * zOffset)) })
                        }
                        if (depths[6] > 0) {
                            vertexPositions.append([0, 6, 4].map { centre + Slice.vertexOffsets[$0] - Vector(0.0, 0.0, (Double(depths[$0] - 1) * zOffset)) })
                        }
                    }
                    
                }
                
                for positions in vertexPositions {
                    if let poly = Polygon(positions.map { Vertex($0, Vector.zero) }, material: material) {
                        polygons.append(poly)
                    }
                }
                
                k += 1
            }
        }
    }
}
