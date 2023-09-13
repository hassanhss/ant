#pragma once

#include <core/ComputedValues.h>
#include <core/Geometry.h>
#include <core/Node.h>
#include <core/Types.h>
#include <core/ElementBackground.h>
#include <css/Property.h>
#include <css/PropertyIdSet.h>
#include <css/PropertyVector.h>
#include <css/StyleCache.h>
#include <optional>
#include <unordered_map>

namespace Rml {

class Document;
class Element;
class ElementAnimation;
class ElementTransition;
class Geometry;
class StyleSheet;
struct HtmlElement;

using ElementAttributes = std::unordered_map<std::string, std::string>;

struct ElementClip {
	enum class Type : uint8_t {
		None,
		Any,
		Scissor,
		Shader,
	} type = Type::None;
	union {
		glm::u16vec4 scissor;
		glm::vec4 shader[2];
	};
};

class Element : public LayoutNode {
public:
	Element(Document* owner, const std::string& tag);
	virtual ~Element();

	std::string GetAddress(bool include_pseudo_classes = false, bool include_parents = true) const;
	bool IgnorePointerEvents() const;

	bool IsRemoved() const;
	float GetOpacity();
	bool IsGray();
	float GetFontSize() const;
	bool UpdataFontSize();

	void SetAttribute(const std::string& name, const std::string& value);
	const std::string* GetAttribute(const std::string& name) const;
	const ElementAttributes& GetAttributes() const;
	void RemoveAttribute(const std::string& name);

	bool Project(Point& point) const noexcept;
	const std::string& GetTagName() const;
	const std::string& GetId() const;
	void SetId(const std::string& id);
	Document* GetOwnerDocument() const;

	void InstanceOuter(const HtmlElement& html);
	void InstanceInner(const HtmlElement& html);
	void NotifyCreated();

	bool DispatchAnimationEvent(const std::string& type, const ElementAnimation& animation);

	void   AppendChild(Node* node, size_t index = size_t(-1));
	void   RemoveChild(Node* node);
	std::unique_ptr<Node> DetachChild(Node* node);
	size_t GetChildNodeIndex(Node* node) const;
	void   InsertBefore(Node* child, Node* adjacent);
	Node*  GetPreviousSibling();
	void   RemoveAllChildren();

	auto const& Children() const { return children; }
	auto const& ChildNodes() const { return childnodes; }
	auto&       Children() { return children; }
	auto&       ChildNodes() { return childnodes; }

	Node* GetChildNode(size_t index) const;
	size_t GetNumChildNodes() const;

	Element* GetElementById(const std::string& id);
	void GetElementsByTagName(const std::string& tag, std::function<void(Element*)> func);
	void GetElementsByClassName(const std::string& class_name, std::function<void(Element*)> func);

	void Update();
	void UpdateRender();
	bool SetRenderStatus();

	Size GetScrollOffset() const;
	float GetScrollLeft() const;
	float GetScrollTop() const;
	void SetScrollLeft(float v);
	void SetScrollTop(float v);
	void SetScrollInsets(const EdgeInsets<float>& insets);
	void UpdateScrollOffset(Size& scrollOffset) const;

	void SetPseudoClass(PseudoClass pseudo_class, bool activate);
	bool IsPseudoClassSet(PseudoClassSet pseudo_class) const;
	PseudoClassSet GetActivePseudoClasses() const;
	bool IsClassSet(const std::string& class_name) const;
	void SetClassName(const std::string& class_names);
	std::string GetClassName() const;
	void DirtyPropertiesWithUnitRecursive(PropertyUnit unit);

	void UpdateDefinition();
	void DirtyDefinition();
	void DirtyInheritableProperties();
	void DirtyProperty(PropertyId id);
	void DirtyProperties(const PropertyIdSet& properties);
	void DirtyProperties(PropertyUnit unit);

	void SetAnimationProperty(PropertyId id, const Property& property);
	void DelAnimationProperty(PropertyId id);

	std::optional<Property> GetInlineProperty(PropertyId id) const;
	std::optional<Property> GetLocalProperty(PropertyId id) const;
	std::optional<Property> GetComputedProperty(PropertyId id) const;
	template <typename T>
	auto GetProperty(PropertyId id) const {
		if constexpr(std::is_same_v<T, float>) {
			return GetComputedProperty(id)->Get<T>(this);
		}
		else {
			return GetComputedProperty(id)->Get<T>();
		}
	}

	bool SetProperty(const std::string& name, std::optional<std::string> value = std::nullopt);
	std::optional<std::string> GetProperty(const std::string& name) const;

	void UpdateProperties();
	void UpdateAnimations(float delta);

	const EdgeInsets<float>& GetPadding() const;
	const EdgeInsets<float>& GetBorder() const;

	void SetParentNode(Element* parent) override;
	Node* Clone(bool deep = true) const override;
	void CalculateLayout() override;
	void Render() override;
	float GetZIndex() const override;
	Element* ElementFromPoint(Point point) override;
	Element* ChildFromPoint(Point point);
	std::string GetInnerHTML() const override;
	std::string GetOuterHTML() const override;
	void SetInnerHTML(const std::string& html) override;
	void SetOuterHTML(const std::string& html) override;
	const Rect& GetContentRect() const override;
	void ChangedProperties(const PropertyIdSet& changed_properties);
	void DirtyBackground();

protected:
	void UpdateStackingContext();
	void DirtyStackingContext();
	void DirtyStructure();
	void UpdateStructure();
	void DirtyPerspective();
	void UpdateTransform();
	void UpdatePerspective();
	void UpdateGeometry();
	void DirtyTransform();
	void DirtyClip();
	void UpdateClip();
	bool SetInlineProperty(const PropertyVector& vec);
	bool DelInlineProperty(const PropertyIdSet& set);
	void RefreshProperties();

	void StartTransition(std::function<void()> f);
	void HandleTransitionProperty();
	void HandleAnimationProperty();
	void AdvanceAnimations(float delta);

	std::string tag;
	std::string id;
	Document* owner_document;
	ElementAttributes attributes;
	std::vector<std::unique_ptr<Node>> childnodes;
	std::vector<Element*> children;
	std::vector<LayoutNode*> render_children;
	std::unique_ptr<glm::mat4x4> perspective;
	mutable bool have_inv_transform = true;
	mutable std::unique_ptr<glm::mat4x4> inv_transform;
	std::map<PropertyId, ElementAnimation> animations;
	std::map<PropertyId, ElementTransition> transitions;
	std::vector<std::string> classes;
	PseudoClassSet pseudo_classes = 0;
	ElementBackground geometry;
	float font_size = 16.f;
	Style::Value animation_properties = Style::Instance().Create();
	Style::Value inline_properties = Style::Instance().Create();
	Style::Value definition_properties = Style::Instance().Create();
	Style::Combination local_properties = Style::Instance().Merge(animation_properties, inline_properties, definition_properties);
	Style::Combination global_properties = Style::Instance().Inherit(local_properties);
	PropertyIdSet dirty_properties;
	glm::mat4x4 transform;
	Rect content_rect;
	EdgeInsets<float> padding{};
	EdgeInsets<float> border{};
	EdgeInsets<float> scroll_insets{};
	ElementClip clip;
	void UnionClip(ElementClip& clip);

	enum class Dirty {
		Transform,
		Clip,
		StackingContext,
		Structure,
		Perspective,
		Animation,
		Transition,
		Background,
		Definition,
	};
	EnumSet<Dirty> dirty;
};

}
